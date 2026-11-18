#include "rubik.h"
#include "cube_tables.h"

enum { SOLVED = 9, DIAMETER_MARK = 16, NO_ENTRY = 31 };

struct coords {
    /* p and o are byte offsets into the permutation and orientation tables. */
    unsigned p;
    unsigned o;
};

static int decode(const char *state, struct coords *c)
{
    unsigned p = 0;
    unsigned o = 0;
    unsigned seen = 0;
    unsigned sum = 0;

    /* The first seven characters list the corners. Each corner must appear once. */
    for (unsigned i = 0; i < 7; ++i) {
        unsigned digit = (unsigned char) state[i] - (unsigned) '1';
        if (digit >= 7 || (seen & (1u << digit)))
            return 0;

        /* Count the unused corners with smaller numbers to get this digit of the permutation rank. */
        unsigned smaller = digit;
        for (unsigned used = seen & ((1u << digit) - 1); used; used &= used - 1)
            --smaller;
        p = p * (7 - i) + smaller;
        seen |= 1u << digit;
    }

    /* The last seven characters give the twists. The first six determine the seventh. */
    for (unsigned i = 0; i < 7; ++i) {
        unsigned digit = (unsigned char) state[i + 7] - (unsigned) '1';
        if (digit >= 3)
            return 0;
        sum += digit;
        if (i < 6)
            o = 3 * o + digit;
    }

    if (state[14] ||
        (sum != 0 && sum != 3 && sum != 6 && sum != 9 && sum != 12))
        return 0;

    c->p = p << 3;
    c->o = o << 3;
    return 1;
}

static struct coords quarter(struct coords c, unsigned face)
{
    return (struct coords) {perm_rows[(c.p >> 1) + face],
                            orient_rows[(c.o >> 1) + face]};
}

/* Each permutation's entries are sorted by orientation. The low five bits hold the move or tag. */
static unsigned lookup(struct coords c)
{
    unsigned index = c.p >> 1;
    unsigned low = perm_rows[index + 3];
    unsigned high = perm_rows[index + 7];
    unsigned key = c.o << 2;

    while (low < high) {
        unsigned entry = dictionary[low++];
        if ((entry & ~31u) == key)
            return entry & 31u;
    }

    return NO_ENTRY;
}

static struct coords apply(struct coords c, unsigned move)
{
    unsigned face = move < 3 ? 0 : move < 6 ? 1 : 2;
    unsigned turns = move - 3 * face + 1;

    do {
        c = quarter(c, face);
    } while (--turns);

    return c;
}

struct frame {
    struct coords start;
    struct coords child;
    unsigned next;
    unsigned skip_face;
};

/* Try up to five moves on the stack. Skip consecutive turns of one face since they combine into one move. */
static int meet(struct coords start,
                unsigned depth,
                uint8_t *moves,
                struct coords *end,
                unsigned *tag)
{
    struct frame stack[5];
    unsigned level = 0;
    stack[0] = (struct frame) {start, start, 0, 3};

    for (;;) {
        struct frame *f = &stack[level];
        if (f->next == 9) {
            if (level == 0)
                return 0;
            --level;
            continue;
        }

        unsigned move = f->next;
        unsigned face = move < 3 ? 0 : move < 6 ? 1 : 2;
        if (face == f->skip_face) {
            f->next += 3;
            continue;
        }

        if (move == 0 || move == 3 || move == 6)
            f->child = f->start;
        f->child = quarter(f->child, face);
        ++f->next;
        moves[level] = (uint8_t) move;

        /* At the target depth, check if the table can finish the solve in five moves or fewer. */
        if (level + 1 == depth) {
            unsigned hit = lookup(f->child);
            if (hit <= SOLVED) {
                *end = f->child;
                *tag = hit;
                return 1;
            }
        } else {
            struct coords child = f->child;
            stack[++level] = (struct frame) {child, child, 0, face};
        }
    }
}

static int write_moves(const uint8_t *moves,
                       unsigned count,
                       char *out,
                       size_t cap)
{
    static const char face[] = "RRRBBBDDD";
    static const char suffix[] = {0, '2', '\'', 0, '2', '\'', 0, '2', '\''};

    /* Count face letters, spaces and the final null byte, then add room for each 2 or prime mark. */
    unsigned needed = count ? 2 * count : 1;
    for (unsigned i = 0; i < count; ++i)
        needed += suffix[moves[i]] != 0;

    if (cap < needed) {
        if (cap)
            out[0] = 0;
        return -2;
    }

    for (unsigned i = 0; i < count; ++i) {
        unsigned m = moves[i];
        if (i)
            *out++ = ' ';
        *out++ = face[m];
        if (suffix[m])
            *out++ = suffix[m];
    }

    *out = 0;
    return (int) count;
}

int rubik_solve(const char *state, char *out, size_t cap)
{
    struct coords pos;
    if (!decode(state, &pos))
        return -1;

    uint8_t moves[11];
    unsigned count = 0;
    unsigned depth = 1;
    unsigned tag = lookup(pos);

    if (tag != NO_ENTRY && tag >= DIAMETER_MARK) {
        moves[count++] = (uint8_t) (tag - DIAMETER_MARK);
        pos = apply(pos, moves[0]);
        /* At distance eleven, take the stored move first. Five more moves can reach the five-move table. */
        depth = 5;
        tag = NO_ENTRY;
    }

    if (tag == NO_ENTRY) {
        for (; depth <= 5; ++depth) {
            if (meet(pos, depth, moves + count, &pos, &tag)) {
                count += depth;
                break;
            }
        }
    }

    /* Follow the stored moves to finish the solve. */
    while (tag < SOLVED) {
        moves[count++] = (uint8_t) tag;
        pos = apply(pos, tag);
        tag = lookup(pos);
    }

    return write_moves(moves, count, out, cap);
}

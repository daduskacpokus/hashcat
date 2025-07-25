/**
 * Author......: See docs/credits.txt
 * License.....: MIT
 */

//#define NEW_SIMD_CODE

#ifdef KERNEL_STATIC
#include M2S(INCLUDE_PATH/inc_vendor.h)
#include M2S(INCLUDE_PATH/inc_types.h)
#include M2S(INCLUDE_PATH/inc_platform.cl)
#include M2S(INCLUDE_PATH/inc_common.cl)
#include M2S(INCLUDE_PATH/inc_rp.h)
#include M2S(INCLUDE_PATH/inc_rp.cl)
#include M2S(INCLUDE_PATH/inc_simd.cl)
#endif

#define PERM_OP(a,b,tt,n,m) \
{                           \
  tt = a >> n;              \
  tt = tt ^ b;              \
  tt = tt & m;              \
  b = b ^ tt;               \
  tt = tt << n;             \
  a = a ^ tt;               \
}

#define HPERM_OP(a,tt,n,m)  \
{                           \
  tt = a << (16 + n);       \
  tt = tt ^ a;              \
  tt = tt & m;              \
  a  = a ^ tt;              \
  tt = tt >> (16 + n);      \
  a  = a ^ tt;              \
}

CONSTANT_VK u32a c_SPtrans[8][64] =
{
  {
    0x00820200, 0x00020000, 0x80800000, 0x80820200,
    0x00800000, 0x80020200, 0x80020000, 0x80800000,
    0x80020200, 0x00820200, 0x00820000, 0x80000200,
    0x80800200, 0x00800000, 0x00000000, 0x80020000,
    0x00020000, 0x80000000, 0x00800200, 0x00020200,
    0x80820200, 0x00820000, 0x80000200, 0x00800200,
    0x80000000, 0x00000200, 0x00020200, 0x80820000,
    0x00000200, 0x80800200, 0x80820000, 0x00000000,
    0x00000000, 0x80820200, 0x00800200, 0x80020000,
    0x00820200, 0x00020000, 0x80000200, 0x00800200,
    0x80820000, 0x00000200, 0x00020200, 0x80800000,
    0x80020200, 0x80000000, 0x80800000, 0x00820000,
    0x80820200, 0x00020200, 0x00820000, 0x80800200,
    0x00800000, 0x80000200, 0x80020000, 0x00000000,
    0x00020000, 0x00800000, 0x80800200, 0x00820200,
    0x80000000, 0x80820000, 0x00000200, 0x80020200,
  },
  {
    0x10042004, 0x00000000, 0x00042000, 0x10040000,
    0x10000004, 0x00002004, 0x10002000, 0x00042000,
    0x00002000, 0x10040004, 0x00000004, 0x10002000,
    0x00040004, 0x10042000, 0x10040000, 0x00000004,
    0x00040000, 0x10002004, 0x10040004, 0x00002000,
    0x00042004, 0x10000000, 0x00000000, 0x00040004,
    0x10002004, 0x00042004, 0x10042000, 0x10000004,
    0x10000000, 0x00040000, 0x00002004, 0x10042004,
    0x00040004, 0x10042000, 0x10002000, 0x00042004,
    0x10042004, 0x00040004, 0x10000004, 0x00000000,
    0x10000000, 0x00002004, 0x00040000, 0x10040004,
    0x00002000, 0x10000000, 0x00042004, 0x10002004,
    0x10042000, 0x00002000, 0x00000000, 0x10000004,
    0x00000004, 0x10042004, 0x00042000, 0x10040000,
    0x10040004, 0x00040000, 0x00002004, 0x10002000,
    0x10002004, 0x00000004, 0x10040000, 0x00042000,
  },
  {
    0x41000000, 0x01010040, 0x00000040, 0x41000040,
    0x40010000, 0x01000000, 0x41000040, 0x00010040,
    0x01000040, 0x00010000, 0x01010000, 0x40000000,
    0x41010040, 0x40000040, 0x40000000, 0x41010000,
    0x00000000, 0x40010000, 0x01010040, 0x00000040,
    0x40000040, 0x41010040, 0x00010000, 0x41000000,
    0x41010000, 0x01000040, 0x40010040, 0x01010000,
    0x00010040, 0x00000000, 0x01000000, 0x40010040,
    0x01010040, 0x00000040, 0x40000000, 0x00010000,
    0x40000040, 0x40010000, 0x01010000, 0x41000040,
    0x00000000, 0x01010040, 0x00010040, 0x41010000,
    0x40010000, 0x01000000, 0x41010040, 0x40000000,
    0x40010040, 0x41000000, 0x01000000, 0x41010040,
    0x00010000, 0x01000040, 0x41000040, 0x00010040,
    0x01000040, 0x00000000, 0x41010000, 0x40000040,
    0x41000000, 0x40010040, 0x00000040, 0x01010000,
  },
  {
    0x00100402, 0x04000400, 0x00000002, 0x04100402,
    0x00000000, 0x04100000, 0x04000402, 0x00100002,
    0x04100400, 0x04000002, 0x04000000, 0x00000402,
    0x04000002, 0x00100402, 0x00100000, 0x04000000,
    0x04100002, 0x00100400, 0x00000400, 0x00000002,
    0x00100400, 0x04000402, 0x04100000, 0x00000400,
    0x00000402, 0x00000000, 0x00100002, 0x04100400,
    0x04000400, 0x04100002, 0x04100402, 0x00100000,
    0x04100002, 0x00000402, 0x00100000, 0x04000002,
    0x00100400, 0x04000400, 0x00000002, 0x04100000,
    0x04000402, 0x00000000, 0x00000400, 0x00100002,
    0x00000000, 0x04100002, 0x04100400, 0x00000400,
    0x04000000, 0x04100402, 0x00100402, 0x00100000,
    0x04100402, 0x00000002, 0x04000400, 0x00100402,
    0x00100002, 0x00100400, 0x04100000, 0x04000402,
    0x00000402, 0x04000000, 0x04000002, 0x04100400,
  },
  {
    0x02000000, 0x00004000, 0x00000100, 0x02004108,
    0x02004008, 0x02000100, 0x00004108, 0x02004000,
    0x00004000, 0x00000008, 0x02000008, 0x00004100,
    0x02000108, 0x02004008, 0x02004100, 0x00000000,
    0x00004100, 0x02000000, 0x00004008, 0x00000108,
    0x02000100, 0x00004108, 0x00000000, 0x02000008,
    0x00000008, 0x02000108, 0x02004108, 0x00004008,
    0x02004000, 0x00000100, 0x00000108, 0x02004100,
    0x02004100, 0x02000108, 0x00004008, 0x02004000,
    0x00004000, 0x00000008, 0x02000008, 0x02000100,
    0x02000000, 0x00004100, 0x02004108, 0x00000000,
    0x00004108, 0x02000000, 0x00000100, 0x00004008,
    0x02000108, 0x00000100, 0x00000000, 0x02004108,
    0x02004008, 0x02004100, 0x00000108, 0x00004000,
    0x00004100, 0x02004008, 0x02000100, 0x00000108,
    0x00000008, 0x00004108, 0x02004000, 0x02000008,
  },
  {
    0x20000010, 0x00080010, 0x00000000, 0x20080800,
    0x00080010, 0x00000800, 0x20000810, 0x00080000,
    0x00000810, 0x20080810, 0x00080800, 0x20000000,
    0x20000800, 0x20000010, 0x20080000, 0x00080810,
    0x00080000, 0x20000810, 0x20080010, 0x00000000,
    0x00000800, 0x00000010, 0x20080800, 0x20080010,
    0x20080810, 0x20080000, 0x20000000, 0x00000810,
    0x00000010, 0x00080800, 0x00080810, 0x20000800,
    0x00000810, 0x20000000, 0x20000800, 0x00080810,
    0x20080800, 0x00080010, 0x00000000, 0x20000800,
    0x20000000, 0x00000800, 0x20080010, 0x00080000,
    0x00080010, 0x20080810, 0x00080800, 0x00000010,
    0x20080810, 0x00080800, 0x00080000, 0x20000810,
    0x20000010, 0x20080000, 0x00080810, 0x00000000,
    0x00000800, 0x20000010, 0x20000810, 0x20080800,
    0x20080000, 0x00000810, 0x00000010, 0x20080010,
  },
  {
    0x00001000, 0x00000080, 0x00400080, 0x00400001,
    0x00401081, 0x00001001, 0x00001080, 0x00000000,
    0x00400000, 0x00400081, 0x00000081, 0x00401000,
    0x00000001, 0x00401080, 0x00401000, 0x00000081,
    0x00400081, 0x00001000, 0x00001001, 0x00401081,
    0x00000000, 0x00400080, 0x00400001, 0x00001080,
    0x00401001, 0x00001081, 0x00401080, 0x00000001,
    0x00001081, 0x00401001, 0x00000080, 0x00400000,
    0x00001081, 0x00401000, 0x00401001, 0x00000081,
    0x00001000, 0x00000080, 0x00400000, 0x00401001,
    0x00400081, 0x00001081, 0x00001080, 0x00000000,
    0x00000080, 0x00400001, 0x00000001, 0x00400080,
    0x00000000, 0x00400081, 0x00400080, 0x00001080,
    0x00000081, 0x00001000, 0x00401081, 0x00400000,
    0x00401080, 0x00000001, 0x00001001, 0x00401081,
    0x00400001, 0x00401080, 0x00401000, 0x00001001,
  },
  {
    0x08200020, 0x08208000, 0x00008020, 0x00000000,
    0x08008000, 0x00200020, 0x08200000, 0x08208020,
    0x00000020, 0x08000000, 0x00208000, 0x00008020,
    0x00208020, 0x08008020, 0x08000020, 0x08200000,
    0x00008000, 0x00208020, 0x00200020, 0x08008000,
    0x08208020, 0x08000020, 0x00000000, 0x00208000,
    0x08000000, 0x00200000, 0x08008020, 0x08200020,
    0x00200000, 0x00008000, 0x08208000, 0x00000020,
    0x00200000, 0x00008000, 0x08000020, 0x08208020,
    0x00008020, 0x08000000, 0x00000000, 0x00208000,
    0x08200020, 0x08008020, 0x08008000, 0x00200020,
    0x08208000, 0x00000020, 0x00200020, 0x08008000,
    0x08208020, 0x00200000, 0x08200000, 0x08000020,
    0x00208000, 0x00008020, 0x08008020, 0x08200000,
    0x00000020, 0x08208000, 0x00208020, 0x00000000,
    0x08000000, 0x08200020, 0x00008000, 0x00208020
  },
};

CONSTANT_VK u32a c_skb[8][64] =
{
  {
    0x00000000, 0x00000010, 0x20000000, 0x20000010,
    0x00010000, 0x00010010, 0x20010000, 0x20010010,
    0x00000800, 0x00000810, 0x20000800, 0x20000810,
    0x00010800, 0x00010810, 0x20010800, 0x20010810,
    0x00000020, 0x00000030, 0x20000020, 0x20000030,
    0x00010020, 0x00010030, 0x20010020, 0x20010030,
    0x00000820, 0x00000830, 0x20000820, 0x20000830,
    0x00010820, 0x00010830, 0x20010820, 0x20010830,
    0x00080000, 0x00080010, 0x20080000, 0x20080010,
    0x00090000, 0x00090010, 0x20090000, 0x20090010,
    0x00080800, 0x00080810, 0x20080800, 0x20080810,
    0x00090800, 0x00090810, 0x20090800, 0x20090810,
    0x00080020, 0x00080030, 0x20080020, 0x20080030,
    0x00090020, 0x00090030, 0x20090020, 0x20090030,
    0x00080820, 0x00080830, 0x20080820, 0x20080830,
    0x00090820, 0x00090830, 0x20090820, 0x20090830,
  },
  {
    0x00000000, 0x02000000, 0x00002000, 0x02002000,
    0x00200000, 0x02200000, 0x00202000, 0x02202000,
    0x00000004, 0x02000004, 0x00002004, 0x02002004,
    0x00200004, 0x02200004, 0x00202004, 0x02202004,
    0x00000400, 0x02000400, 0x00002400, 0x02002400,
    0x00200400, 0x02200400, 0x00202400, 0x02202400,
    0x00000404, 0x02000404, 0x00002404, 0x02002404,
    0x00200404, 0x02200404, 0x00202404, 0x02202404,
    0x10000000, 0x12000000, 0x10002000, 0x12002000,
    0x10200000, 0x12200000, 0x10202000, 0x12202000,
    0x10000004, 0x12000004, 0x10002004, 0x12002004,
    0x10200004, 0x12200004, 0x10202004, 0x12202004,
    0x10000400, 0x12000400, 0x10002400, 0x12002400,
    0x10200400, 0x12200400, 0x10202400, 0x12202400,
    0x10000404, 0x12000404, 0x10002404, 0x12002404,
    0x10200404, 0x12200404, 0x10202404, 0x12202404,
  },
  {
    0x00000000, 0x00000001, 0x00040000, 0x00040001,
    0x01000000, 0x01000001, 0x01040000, 0x01040001,
    0x00000002, 0x00000003, 0x00040002, 0x00040003,
    0x01000002, 0x01000003, 0x01040002, 0x01040003,
    0x00000200, 0x00000201, 0x00040200, 0x00040201,
    0x01000200, 0x01000201, 0x01040200, 0x01040201,
    0x00000202, 0x00000203, 0x00040202, 0x00040203,
    0x01000202, 0x01000203, 0x01040202, 0x01040203,
    0x08000000, 0x08000001, 0x08040000, 0x08040001,
    0x09000000, 0x09000001, 0x09040000, 0x09040001,
    0x08000002, 0x08000003, 0x08040002, 0x08040003,
    0x09000002, 0x09000003, 0x09040002, 0x09040003,
    0x08000200, 0x08000201, 0x08040200, 0x08040201,
    0x09000200, 0x09000201, 0x09040200, 0x09040201,
    0x08000202, 0x08000203, 0x08040202, 0x08040203,
    0x09000202, 0x09000203, 0x09040202, 0x09040203,
  },
  {
    0x00000000, 0x00100000, 0x00000100, 0x00100100,
    0x00000008, 0x00100008, 0x00000108, 0x00100108,
    0x00001000, 0x00101000, 0x00001100, 0x00101100,
    0x00001008, 0x00101008, 0x00001108, 0x00101108,
    0x04000000, 0x04100000, 0x04000100, 0x04100100,
    0x04000008, 0x04100008, 0x04000108, 0x04100108,
    0x04001000, 0x04101000, 0x04001100, 0x04101100,
    0x04001008, 0x04101008, 0x04001108, 0x04101108,
    0x00020000, 0x00120000, 0x00020100, 0x00120100,
    0x00020008, 0x00120008, 0x00020108, 0x00120108,
    0x00021000, 0x00121000, 0x00021100, 0x00121100,
    0x00021008, 0x00121008, 0x00021108, 0x00121108,
    0x04020000, 0x04120000, 0x04020100, 0x04120100,
    0x04020008, 0x04120008, 0x04020108, 0x04120108,
    0x04021000, 0x04121000, 0x04021100, 0x04121100,
    0x04021008, 0x04121008, 0x04021108, 0x04121108,
  },
  {
    0x00000000, 0x10000000, 0x00010000, 0x10010000,
    0x00000004, 0x10000004, 0x00010004, 0x10010004,
    0x20000000, 0x30000000, 0x20010000, 0x30010000,
    0x20000004, 0x30000004, 0x20010004, 0x30010004,
    0x00100000, 0x10100000, 0x00110000, 0x10110000,
    0x00100004, 0x10100004, 0x00110004, 0x10110004,
    0x20100000, 0x30100000, 0x20110000, 0x30110000,
    0x20100004, 0x30100004, 0x20110004, 0x30110004,
    0x00001000, 0x10001000, 0x00011000, 0x10011000,
    0x00001004, 0x10001004, 0x00011004, 0x10011004,
    0x20001000, 0x30001000, 0x20011000, 0x30011000,
    0x20001004, 0x30001004, 0x20011004, 0x30011004,
    0x00101000, 0x10101000, 0x00111000, 0x10111000,
    0x00101004, 0x10101004, 0x00111004, 0x10111004,
    0x20101000, 0x30101000, 0x20111000, 0x30111000,
    0x20101004, 0x30101004, 0x20111004, 0x30111004,
  },
  {
    0x00000000, 0x08000000, 0x00000008, 0x08000008,
    0x00000400, 0x08000400, 0x00000408, 0x08000408,
    0x00020000, 0x08020000, 0x00020008, 0x08020008,
    0x00020400, 0x08020400, 0x00020408, 0x08020408,
    0x00000001, 0x08000001, 0x00000009, 0x08000009,
    0x00000401, 0x08000401, 0x00000409, 0x08000409,
    0x00020001, 0x08020001, 0x00020009, 0x08020009,
    0x00020401, 0x08020401, 0x00020409, 0x08020409,
    0x02000000, 0x0A000000, 0x02000008, 0x0A000008,
    0x02000400, 0x0A000400, 0x02000408, 0x0A000408,
    0x02020000, 0x0A020000, 0x02020008, 0x0A020008,
    0x02020400, 0x0A020400, 0x02020408, 0x0A020408,
    0x02000001, 0x0A000001, 0x02000009, 0x0A000009,
    0x02000401, 0x0A000401, 0x02000409, 0x0A000409,
    0x02020001, 0x0A020001, 0x02020009, 0x0A020009,
    0x02020401, 0x0A020401, 0x02020409, 0x0A020409,
  },
  {
    0x00000000, 0x00000100, 0x00080000, 0x00080100,
    0x01000000, 0x01000100, 0x01080000, 0x01080100,
    0x00000010, 0x00000110, 0x00080010, 0x00080110,
    0x01000010, 0x01000110, 0x01080010, 0x01080110,
    0x00200000, 0x00200100, 0x00280000, 0x00280100,
    0x01200000, 0x01200100, 0x01280000, 0x01280100,
    0x00200010, 0x00200110, 0x00280010, 0x00280110,
    0x01200010, 0x01200110, 0x01280010, 0x01280110,
    0x00000200, 0x00000300, 0x00080200, 0x00080300,
    0x01000200, 0x01000300, 0x01080200, 0x01080300,
    0x00000210, 0x00000310, 0x00080210, 0x00080310,
    0x01000210, 0x01000310, 0x01080210, 0x01080310,
    0x00200200, 0x00200300, 0x00280200, 0x00280300,
    0x01200200, 0x01200300, 0x01280200, 0x01280300,
    0x00200210, 0x00200310, 0x00280210, 0x00280310,
    0x01200210, 0x01200310, 0x01280210, 0x01280310,
  },
  {
    0x00000000, 0x04000000, 0x00040000, 0x04040000,
    0x00000002, 0x04000002, 0x00040002, 0x04040002,
    0x00002000, 0x04002000, 0x00042000, 0x04042000,
    0x00002002, 0x04002002, 0x00042002, 0x04042002,
    0x00000020, 0x04000020, 0x00040020, 0x04040020,
    0x00000022, 0x04000022, 0x00040022, 0x04040022,
    0x00002020, 0x04002020, 0x00042020, 0x04042020,
    0x00002022, 0x04002022, 0x00042022, 0x04042022,
    0x00000800, 0x04000800, 0x00040800, 0x04040800,
    0x00000802, 0x04000802, 0x00040802, 0x04040802,
    0x00002800, 0x04002800, 0x00042800, 0x04042800,
    0x00002802, 0x04002802, 0x00042802, 0x04042802,
    0x00000820, 0x04000820, 0x00040820, 0x04040820,
    0x00000822, 0x04000822, 0x00040822, 0x04040822,
    0x00002820, 0x04002820, 0x00042820, 0x04042820,
    0x00002822, 0x04002822, 0x00042822, 0x04042822
  },
};

#if   VECT_SIZE == 1
#define BOX(i,n,S) (S)[(n)][(i)]
#elif VECT_SIZE == 2
#define BOX(i,n,S) make_u32x ((S)[(n)][(i).s0], (S)[(n)][(i).s1])
#elif VECT_SIZE == 4
#define BOX(i,n,S) make_u32x ((S)[(n)][(i).s0], (S)[(n)][(i).s1], (S)[(n)][(i).s2], (S)[(n)][(i).s3])
#elif VECT_SIZE == 8
#define BOX(i,n,S) make_u32x ((S)[(n)][(i).s0], (S)[(n)][(i).s1], (S)[(n)][(i).s2], (S)[(n)][(i).s3], (S)[(n)][(i).s4], (S)[(n)][(i).s5], (S)[(n)][(i).s6], (S)[(n)][(i).s7])
#elif VECT_SIZE == 16
#define BOX(i,n,S) make_u32x ((S)[(n)][(i).s0], (S)[(n)][(i).s1], (S)[(n)][(i).s2], (S)[(n)][(i).s3], (S)[(n)][(i).s4], (S)[(n)][(i).s5], (S)[(n)][(i).s6], (S)[(n)][(i).s7], (S)[(n)][(i).s8], (S)[(n)][(i).s9], (S)[(n)][(i).sa], (S)[(n)][(i).sb], (S)[(n)][(i).sc], (S)[(n)][(i).sd], (S)[(n)][(i).se], (S)[(n)][(i).sf])
#endif

DECLSPEC void _des_crypt_keysetup (u32 c, u32x d, PRIVATE_AS u32x *Kc, PRIVATE_AS  u32x *Kd, LOCAL_AS u32 (*s_skb)[64])
{
  u32 tt;

  PERM_OP  (d, c, tt, 4, 0x0f0f0f0f);
  HPERM_OP (c,    tt, 2, 0xcccc0000);
  HPERM_OP (d,    tt, 2, 0xcccc0000);
  PERM_OP  (d, c, tt, 1, 0x55555555);
  PERM_OP  (c, d, tt, 8, 0x00ff00ff);
  PERM_OP  (d, c, tt, 1, 0x55555555);

  d = ((d & 0x000000ff) << 16)
    | ((d & 0x0000ff00) <<  0)
    | ((d & 0x00ff0000) >> 16)
    | ((c & 0xf0000000) >>  4);

  c = c & 0x0fffffff;

  #ifdef _unroll
  #pragma unroll
  #endif
  for (u32 i = 0; i < 16; i++)
  {
    if ((i < 2) || (i == 8) || (i == 15))
    {
      c = ((c >> 1) | (c << 27));
      d = ((d >> 1) | (d << 27));
    }
    else
    {
      c = ((c >> 2) | (c << 26));
      d = ((d >> 2) | (d << 26));
    }

    c = c & 0x0fffffff;
    d = d & 0x0fffffff;

    const u32 c00 = (c >>  0) & 0x0000003f;
    const u32 c06 = (c >>  6) & 0x00383003;
    const u32 c07 = (c >>  7) & 0x0000003c;
    const u32 c13 = (c >> 13) & 0x0000060f;
    const u32 c20 = (c >> 20) & 0x00000001;

    u32 s = BOX (((c00 >>  0) & 0xff), 0, s_skb)
          | BOX (((c06 >>  0) & 0xff)
                |((c07 >>  0) & 0xff), 1, s_skb)
          | BOX (((c13 >>  0) & 0xff)
                |((c06 >>  8) & 0xff), 2, s_skb)
          | BOX (((c20 >>  0) & 0xff)
                |((c13 >>  8) & 0xff)
                |((c06 >> 16) & 0xff), 3, s_skb);

    const u32 d00 = (d >>  0) & 0x00003c3f;
    const u32 d07 = (d >>  7) & 0x00003f03;
    const u32 d21 = (d >> 21) & 0x0000000f;
    const u32 d22 = (d >> 22) & 0x00000030;

    u32 t = BOX (((d00 >>  0) & 0xff), 4, s_skb)
          | BOX (((d07 >>  0) & 0xff)
                |((d00 >>  8) & 0xff), 5, s_skb)
          | BOX (((d07 >>  8) & 0xff), 6, s_skb)
          | BOX (((d21 >>  0) & 0xff)
                |((d22 >>  0) & 0xff), 7, s_skb);

    Kc[i] = ((t << 16) | (s & 0x0000ffff));
    Kd[i] = ((s >> 16) | (t & 0xffff0000));
  }
}

DECLSPEC void _des_crypt_encrypt (PRIVATE_AS  u32 *iv, u32 mask, PRIVATE_AS  u32x *Kc, PRIVATE_AS  u32x *Kd, LOCAL_AS u32 (*s_SPtrans)[64])
{
  const u32 E1 = (mask >> 2) & 0x3f0;
  const u32 E0 = mask & 0x3f;

  u32 r = 0;
  u32 l = 0;

  for (u32 i = 0; i < 25; i++)
  {
    #ifdef _unroll
    #pragma unroll
    #endif
    for (u32 j = 0; j < 16; j += 2)
    {
      u32 t;
      u32 u;

      t = r ^ (r >> 16);
      u = t & E0;
      t = t & E1;
      u = u ^ (u << 16);
      u = u ^ r;
      u = u ^ Kc[j + 0];
      t = t ^ (t << 16);
      t = t ^ r;
      t = hc_rotl32 (t, 28u);
      t = t ^ Kd[j + 0];

      l ^= BOX (((u >>  0) & 0x3f), 0, s_SPtrans)
         | BOX (((u >>  8) & 0x3f), 2, s_SPtrans)
         | BOX (((u >> 16) & 0x3f), 4, s_SPtrans)
         | BOX (((u >> 24) & 0x3f), 6, s_SPtrans)
         | BOX (((t >>  0) & 0x3f), 1, s_SPtrans)
         | BOX (((t >>  8) & 0x3f), 3, s_SPtrans)
         | BOX (((t >> 16) & 0x3f), 5, s_SPtrans)
         | BOX (((t >> 24) & 0x3f), 7, s_SPtrans);

      t = l ^ (l >> 16);
      u = t & E0;
      t = t & E1;
      u = u ^ (u << 16);
      u = u ^ l;
      u = u ^ Kc[j + 1];
      t = t ^ (t << 16);
      t = t ^ l;
      t = hc_rotl32 (t, 28u);
      t = t ^ Kd[j + 1];

      r ^= BOX (((u >>  0) & 0x3f), 0, s_SPtrans)
         | BOX (((u >>  8) & 0x3f), 2, s_SPtrans)
         | BOX (((u >> 16) & 0x3f), 4, s_SPtrans)
         | BOX (((u >> 24) & 0x3f), 6, s_SPtrans)
         | BOX (((t >>  0) & 0x3f), 1, s_SPtrans)
         | BOX (((t >>  8) & 0x3f), 3, s_SPtrans)
         | BOX (((t >> 16) & 0x3f), 5, s_SPtrans)
         | BOX (((t >> 24) & 0x3f), 7, s_SPtrans);
    }

    u32 tt;

    tt = l;
    l  = r;
    r  = tt;
  }

  iv[0] = hc_rotl32 (r, 31);
  iv[1] = hc_rotl32 (l, 31);
}

KERNEL_FQ KERNEL_FA void m01500_mxx (KERN_ATTR_RULES ())
{
  /**
   * modifier
   */

  const u64 gid = get_global_id (0);
  const u64 lid = get_local_id (0);
  const u64 lsz = get_local_size (0);

  /**
   * sbox, kbox
   */

  LOCAL_VK u32 s_SPtrans[8][64];
  LOCAL_VK u32 s_skb[8][64];

  for (u32 i = lid; i < 64; i += lsz)
  {
    s_SPtrans[0][i] = c_SPtrans[0][i];
    s_SPtrans[1][i] = c_SPtrans[1][i];
    s_SPtrans[2][i] = c_SPtrans[2][i];
    s_SPtrans[3][i] = c_SPtrans[3][i];
    s_SPtrans[4][i] = c_SPtrans[4][i];
    s_SPtrans[5][i] = c_SPtrans[5][i];
    s_SPtrans[6][i] = c_SPtrans[6][i];
    s_SPtrans[7][i] = c_SPtrans[7][i];

    s_skb[0][i] = c_skb[0][i];
    s_skb[1][i] = c_skb[1][i];
    s_skb[2][i] = c_skb[2][i];
    s_skb[3][i] = c_skb[3][i];
    s_skb[4][i] = c_skb[4][i];
    s_skb[5][i] = c_skb[5][i];
    s_skb[6][i] = c_skb[6][i];
    s_skb[7][i] = c_skb[7][i];
  }

  SYNC_THREADS ();

  if (gid >= GID_CNT) return;

  /**
   * base
   */

  COPY_PW (pws[gid]);

  /**
   * salt
   */

  const u32 mask = salt_bufs[SALT_POS_HOST].salt_buf[0];

  /**
   * main
   */

  for (u32 il_pos = 0; il_pos < IL_CNT; il_pos += VECT_SIZE)
  {
    pw_t tmp = PASTE_PW;

    tmp.pw_len = apply_rules (rules_buf[il_pos].cmds, tmp.i, tmp.pw_len);

    u32 data[2];

    data[0] = (tmp.i[0] << 1) & 0xfefefefe;
    data[1] = (tmp.i[1] << 1) & 0xfefefefe;

    u32 Kc[16];
    u32 Kd[16];

    _des_crypt_keysetup (data[0], data[1], Kc, Kd, s_skb);

    u32 iv[2];

    _des_crypt_encrypt (iv, mask, Kc, Kd, s_SPtrans);

    u32 z = 0;

    COMPARE_M_SIMD (iv[0], iv[1], z, z);
  }
}

KERNEL_FQ KERNEL_FA void m01500_sxx (KERN_ATTR_RULES ())
{
  /**
   * modifier
   */

  const u64 gid = get_global_id (0);
  const u64 lid = get_local_id (0);
  const u64 lsz = get_local_size (0);

  /**
   * sbox, kbox
   */

  LOCAL_VK u32 s_SPtrans[8][64];
  LOCAL_VK u32 s_skb[8][64];

  for (u32 i = lid; i < 64; i += lsz)
  {
    s_SPtrans[0][i] = c_SPtrans[0][i];
    s_SPtrans[1][i] = c_SPtrans[1][i];
    s_SPtrans[2][i] = c_SPtrans[2][i];
    s_SPtrans[3][i] = c_SPtrans[3][i];
    s_SPtrans[4][i] = c_SPtrans[4][i];
    s_SPtrans[5][i] = c_SPtrans[5][i];
    s_SPtrans[6][i] = c_SPtrans[6][i];
    s_SPtrans[7][i] = c_SPtrans[7][i];

    s_skb[0][i] = c_skb[0][i];
    s_skb[1][i] = c_skb[1][i];
    s_skb[2][i] = c_skb[2][i];
    s_skb[3][i] = c_skb[3][i];
    s_skb[4][i] = c_skb[4][i];
    s_skb[5][i] = c_skb[5][i];
    s_skb[6][i] = c_skb[6][i];
    s_skb[7][i] = c_skb[7][i];
  }

  SYNC_THREADS ();

  if (gid >= GID_CNT) return;

  /**
   * base
   */

  COPY_PW (pws[gid]);

  /**
   * salt
   */

  const u32 mask = salt_bufs[SALT_POS_HOST].salt_buf[0];

  /**
   * digest
   */

  const u32 search[4] =
  {
    digests_buf[DIGESTS_OFFSET_HOST].digest_buf[DGST_R0],
    digests_buf[DIGESTS_OFFSET_HOST].digest_buf[DGST_R1],
    0,
    0
  };

  /**
   * main
   */

  for (u32 il_pos = 0; il_pos < IL_CNT; il_pos += VECT_SIZE)
  {
    pw_t tmp = PASTE_PW;

    tmp.pw_len = apply_rules (rules_buf[il_pos].cmds, tmp.i, tmp.pw_len);

    u32 data[2];

    data[0] = (tmp.i[0] << 1) & 0xfefefefe;
    data[1] = (tmp.i[1] << 1) & 0xfefefefe;

    u32 Kc[16];
    u32 Kd[16];

    _des_crypt_keysetup (data[0], data[1], Kc, Kd, s_skb);

    u32 iv[2];

    _des_crypt_encrypt (iv, mask, Kc, Kd, s_SPtrans);

    u32 z = 0;

    COMPARE_S_SIMD (iv[0], iv[1], z, z);
  }
}

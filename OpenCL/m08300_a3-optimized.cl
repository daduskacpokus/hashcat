/**
 * Author......: See docs/credits.txt
 * License.....: MIT
 */

#define NEW_SIMD_CODE

#ifdef KERNEL_STATIC
#include M2S(INCLUDE_PATH/inc_vendor.h)
#include M2S(INCLUDE_PATH/inc_types.h)
#include M2S(INCLUDE_PATH/inc_platform.cl)
#include M2S(INCLUDE_PATH/inc_common.cl)
#include M2S(INCLUDE_PATH/inc_simd.cl)
#include M2S(INCLUDE_PATH/inc_hash_sha1.cl)
#endif

DECLSPEC u64 u32_to_u64 (const u32 in)
{
  const u64 t0 = (u64) ((in >> 24) & 0xff);
  const u64 t1 = (u64) ((in >> 16) & 0xff);
  const u64 t2 = (u64) ((in >>  8) & 0xff);
  const u64 t3 = (u64) ((in >>  0) & 0xff);

  const u64 out = (t0 << 48)
                | (t1 << 32)
                | (t2 << 16)
                | (t3 <<  0);

  return out;
}

DECLSPEC u32 u64_to_u32 (const u64 in)
{
  const u32 t0 = (u32) ((in >> 48) & 0xff);
  const u32 t1 = (u32) ((in >> 32) & 0xff);
  const u32 t2 = (u32) ((in >> 16) & 0xff);
  const u32 t3 = (u32) ((in >>  0) & 0xff);

  const u32 out = (t0 << 24)
                | (t1 << 16)
                | (t2 <<  8)
                | (t3 <<  0);

  return out;
}

DECLSPEC int replace_u32_be (const u32 input, PRIVATE_AS u32 *output, int cur_len)
{
  // expand to keep 9th bit consistent

  u64 input64 = u32_to_u64 (input);

  u64 m64 = input64;

  m64 ^= 0x002e002e002e002eUL;  // convert 0x2e to 0x00
  m64 ^= 0x00ff00ff00ff00ffUL;  // convert 0x00 to 0xff (jit will optimize this to one instruction)
  m64 += 0x0001000100010001UL;  // only 0xff can set 9th bit
  m64 &= 0x0100010001000100UL;  // only 9th bit survives

  m64 |= m64 << 1;              // converts 0x0100 to 0xff00
  m64 |= m64 << 2;
  m64 |= m64 << 4;

  m64 >>= 8;                    // back to original positions (in 64 bit)

  u32 m = u64_to_u32 (m64);

  u32 r = 0;

  const u32 mn = ~m;

  const u32 r0 = mn & 0xff000000;
  const u32 r1 = mn & 0x00ff0000;
  const u32 r2 = mn & 0x0000ff00;
  const u32 r3 = mn & 0x000000ff;

  r |= cur_len; cur_len = (cur_len + 0x00000001) & r3; cur_len <<= 8;
  r |= cur_len; cur_len = (cur_len + 0x00000100) & r2; cur_len <<= 8;
  r |= cur_len; cur_len = (cur_len + 0x00010000) & r1; cur_len <<= 8;
  r |= cur_len; cur_len = (cur_len + 0x01000000) & r0; cur_len >>= 24;

  *output = (input & mn) | (r & m);

  return cur_len;
}

DECLSPEC u32 replace_dot_by_len (PRIVATE_AS u32 *w0, PRIVATE_AS u32 *w1, PRIVATE_AS u32 *w2, PRIVATE_AS u32 *w3, const u32 pw_len)
{
  // loop over w3...w0 (4 * 16 = 64 bytes):

  int cur_len = 0 - (64 - pw_len); // number of padding bytes relative to buffer size

  cur_len = replace_u32_be (w3[3], &w3[3], cur_len);
  cur_len = replace_u32_be (w3[2], &w3[2], cur_len);
  cur_len = replace_u32_be (w3[1], &w3[1], cur_len);
  cur_len = replace_u32_be (w3[0], &w3[0], cur_len);
  cur_len = replace_u32_be (w2[3], &w2[3], cur_len);
  cur_len = replace_u32_be (w2[2], &w2[2], cur_len);
  cur_len = replace_u32_be (w2[1], &w2[1], cur_len);
  cur_len = replace_u32_be (w2[0], &w2[0], cur_len);
  cur_len = replace_u32_be (w1[3], &w1[3], cur_len);
  cur_len = replace_u32_be (w1[2], &w1[2], cur_len);
  cur_len = replace_u32_be (w1[1], &w1[1], cur_len);
  cur_len = replace_u32_be (w1[0], &w1[0], cur_len);
  cur_len = replace_u32_be (w0[3], &w0[3], cur_len);
  cur_len = replace_u32_be (w0[2], &w0[2], cur_len);
  cur_len = replace_u32_be (w0[1], &w0[1], cur_len);
  cur_len = replace_u32_be (w0[0], &w0[0], cur_len);

  return cur_len;
}

#define REPLACE_DOT_BY_LEN_VECT(n)                                       \
  {                                                                      \
    u32 tmp0[4];                                                         \
                                                                         \
    tmp0[0] = w0_t[0].s##n;                                              \
    tmp0[1] = w0_t[1].s##n;                                              \
    tmp0[2] = w0_t[2].s##n;                                              \
    tmp0[3] = w0_t[3].s##n;                                              \
                                                                         \
    u32 tmp1[4];                                                         \
                                                                         \
    tmp1[0] = w1_t[0].s##n;                                              \
    tmp1[1] = w1_t[1].s##n;                                              \
    tmp1[2] = w1_t[2].s##n;                                              \
    tmp1[3] = w1_t[3].s##n;                                              \
                                                                         \
    u32 tmp2[4];                                                         \
                                                                         \
    tmp2[0] = w2_t[0].s##n;                                              \
    tmp2[1] = w2_t[1].s##n;                                              \
    tmp2[2] = w2_t[2].s##n;                                              \
    tmp2[3] = w2_t[3].s##n;                                              \
                                                                         \
    u32 tmp3[4];                                                         \
                                                                         \
    tmp3[0] = w3_t[0].s##n;                                              \
    tmp3[1] = w3_t[1].s##n;                                              \
    tmp3[2] = w3_t[2].s##n;                                              \
    tmp3[3] = w3_t[3].s##n;                                              \
                                                                         \
    const u32 len = replace_dot_by_len (tmp0, tmp1, tmp2, tmp3, pw_len); \
                                                                         \
    switch_buffer_by_offset_be_S (tmp0, tmp1, tmp2, tmp3, 1);            \
                                                                         \
    tmp0[0] |= (len & 0xff) << 24;                                       \
                                                                         \
    w0_t[0].s##n = tmp0[0];                                              \
    w0_t[1].s##n = tmp0[1];                                              \
    w0_t[2].s##n = tmp0[2];                                              \
    w0_t[3].s##n = tmp0[3];                                              \
                                                                         \
    w1_t[0].s##n = tmp1[0];                                              \
    w1_t[1].s##n = tmp1[1];                                              \
    w1_t[2].s##n = tmp1[2];                                              \
    w1_t[3].s##n = tmp1[3];                                              \
                                                                         \
    w2_t[0].s##n = tmp2[0];                                              \
    w2_t[1].s##n = tmp2[1];                                              \
    w2_t[2].s##n = tmp2[2];                                              \
    w2_t[3].s##n = tmp2[3];                                              \
                                                                         \
    w3_t[0].s##n = tmp3[0];                                              \
    w3_t[1].s##n = tmp3[1];                                              \
    w3_t[2].s##n = tmp3[2];                                              \
    w3_t[3].s##n = tmp3[3];                                              \
  }

DECLSPEC void m08300m (PRIVATE_AS u32 *w0, PRIVATE_AS u32 *w1, PRIVATE_AS u32 *w2, PRIVATE_AS u32 *w3, const u32 pw_len, KERN_ATTR_FUNC_BASIC ())
{
  /**
   * modifiers are taken from args
   */

  /**
   * salt
   */

  const u32 salt_iter = salt_bufs[SALT_POS_HOST].salt_iter;

  u32 salt_buf0[4];
  u32 salt_buf1[4];

  salt_buf0[0] = hc_swap32_S (salt_bufs[SALT_POS_HOST].salt_buf[ 0]);
  salt_buf0[1] = hc_swap32_S (salt_bufs[SALT_POS_HOST].salt_buf[ 1]);
  salt_buf0[2] = hc_swap32_S (salt_bufs[SALT_POS_HOST].salt_buf[ 2]);
  salt_buf0[3] = hc_swap32_S (salt_bufs[SALT_POS_HOST].salt_buf[ 3]);
  salt_buf1[0] = hc_swap32_S (salt_bufs[SALT_POS_HOST].salt_buf[ 4]);
  salt_buf1[1] = hc_swap32_S (salt_bufs[SALT_POS_HOST].salt_buf[ 5]);
  salt_buf1[2] = hc_swap32_S (salt_bufs[SALT_POS_HOST].salt_buf[ 6]);
  salt_buf1[3] = hc_swap32_S (salt_bufs[SALT_POS_HOST].salt_buf[ 7]);

  const u32 salt_len = salt_bufs[SALT_POS_HOST].salt_len;

  u32 domain_buf0[4];
  u32 domain_buf1[4];

  domain_buf0[0] = hc_swap32_S (salt_bufs[SALT_POS_HOST].salt_buf_pc[ 0]);
  domain_buf0[1] = hc_swap32_S (salt_bufs[SALT_POS_HOST].salt_buf_pc[ 1]);
  domain_buf0[2] = hc_swap32_S (salt_bufs[SALT_POS_HOST].salt_buf_pc[ 2]);
  domain_buf0[3] = hc_swap32_S (salt_bufs[SALT_POS_HOST].salt_buf_pc[ 3]);
  domain_buf1[0] = hc_swap32_S (salt_bufs[SALT_POS_HOST].salt_buf_pc[ 4]);
  domain_buf1[1] = hc_swap32_S (salt_bufs[SALT_POS_HOST].salt_buf_pc[ 5]);
  domain_buf1[2] = hc_swap32_S (salt_bufs[SALT_POS_HOST].salt_buf_pc[ 6]);
  domain_buf1[3] = 0;

  const u32 domain_len = salt_bufs[SALT_POS_HOST].salt_len_pc;

  u32 s0[4];
  u32 s1[4];
  u32 s2[4];
  u32 s3[4];

  s0[0] = domain_buf0[0];
  s0[1] = domain_buf0[1];
  s0[2] = domain_buf0[2];
  s0[3] = domain_buf0[3];
  s1[0] = domain_buf1[0];
  s1[1] = domain_buf1[1];
  s1[2] = domain_buf1[2];
  s1[3] = domain_buf1[3];
  s2[0] = 0;
  s2[1] = 0;
  s2[2] = 0;
  s2[3] = 0;
  s3[0] = 0;
  s3[1] = 0;
  s3[2] = 0;
  s3[3] = 0;

  switch_buffer_by_offset_be_S (s0, s1, s2, s3, pw_len);

  w0[0] |= s0[0];
  w0[1] |= s0[1];
  w0[2] |= s0[2];
  w0[3] |= s0[3];
  w1[0] |= s1[0];
  w1[1] |= s1[1];
  w1[2] |= s1[2];
  w1[3] |= s1[3];
  w2[0] |= s2[0];
  w2[1] |= s2[1];
  w2[2] |= s2[2];
  w2[3] |= s2[3];
  w3[0] |= s3[0];
  w3[1] |= s3[1];
  w3[2] |= s3[2];
  w3[3] |= s3[3];

  s0[0] = salt_buf0[0];
  s0[1] = salt_buf0[1];
  s0[2] = salt_buf0[2];
  s0[3] = salt_buf0[3];
  s1[0] = salt_buf1[0];
  s1[1] = salt_buf1[1];
  s1[2] = salt_buf1[2];
  s1[3] = salt_buf1[3];
  s2[0] = 0;
  s2[1] = 0;
  s2[2] = 0;
  s2[3] = 0;
  s3[0] = 0;
  s3[1] = 0;
  s3[2] = 0;
  s3[3] = 0;

  switch_buffer_by_offset_be_S (s0, s1, s2, s3, pw_len + domain_len + 1);

  w0[0] |= s0[0];
  w0[1] |= s0[1];
  w0[2] |= s0[2];
  w0[3] |= s0[3];
  w1[0] |= s1[0];
  w1[1] |= s1[1];
  w1[2] |= s1[2];
  w1[3] |= s1[3];
  w2[0] |= s2[0];
  w2[1] |= s2[1];
  w2[2] |= s2[2];
  w2[3] |= s2[3];
  w3[0] |= s3[0];
  w3[1] |= s3[1];
  w3[2] |= s3[2];
  w3[3] |= s3[3];

  /**
   * loop
   */

  u32 w0l = w0[0];

  for (u32 il_pos = 0; il_pos < IL_CNT; il_pos += VECT_SIZE)
  {
    const u32x w0r = ix_create_bft (bfs_buf, il_pos);

    const u32x w0lr = w0l | w0r;

    u32x w0_t[4];
    u32x w1_t[4];
    u32x w2_t[4];
    u32x w3_t[4];

    w0_t[0] = w0lr;
    w0_t[1] = w0[1];
    w0_t[2] = w0[2];
    w0_t[3] = w0[3];
    w1_t[0] = w1[0];
    w1_t[1] = w1[1];
    w1_t[2] = w1[2];
    w1_t[3] = w1[3];
    w2_t[0] = w2[0];
    w2_t[1] = w2[1];
    w2_t[2] = w2[2];
    w2_t[3] = w2[3];
    w3_t[0] = w3[0];
    w3_t[1] = w3[1];
    w3_t[2] = w3[2];
    w3_t[3] = w3[3];

    // replace "." with the length:

    #if VECT_SIZE == 1
      const u32 len = replace_dot_by_len (w0_t, w1_t, w2_t, w3_t, pw_len);

      switch_buffer_by_offset_be (w0_t, w1_t, w2_t, w3_t, 1);

      w0_t[0] |= (len & 0xff) << 24;
    #endif
    #if VECT_SIZE >= 2
      REPLACE_DOT_BY_LEN_VECT (0)
      REPLACE_DOT_BY_LEN_VECT (1)
    #endif
    #if VECT_SIZE >= 4
      REPLACE_DOT_BY_LEN_VECT (2)
      REPLACE_DOT_BY_LEN_VECT (3)
    #endif
    #if VECT_SIZE >= 8
      REPLACE_DOT_BY_LEN_VECT (4)
      REPLACE_DOT_BY_LEN_VECT (5)
      REPLACE_DOT_BY_LEN_VECT (6)
      REPLACE_DOT_BY_LEN_VECT (7)
    #endif
    #if VECT_SIZE >= 16
      REPLACE_DOT_BY_LEN_VECT (8)
      REPLACE_DOT_BY_LEN_VECT (9)
      REPLACE_DOT_BY_LEN_VECT (a)
      REPLACE_DOT_BY_LEN_VECT (b)
      REPLACE_DOT_BY_LEN_VECT (c)
      REPLACE_DOT_BY_LEN_VECT (d)
      REPLACE_DOT_BY_LEN_VECT (e)
      REPLACE_DOT_BY_LEN_VECT (f)
    #endif

    w3_t[2]  = 0;
    w3_t[3]  = (1 + pw_len + domain_len + 1 + salt_len) * 8;

    /**
     * sha1
     */

    u32x digest[5];

    digest[0] = SHA1M_A;
    digest[1] = SHA1M_B;
    digest[2] = SHA1M_C;
    digest[3] = SHA1M_D;
    digest[4] = SHA1M_E;

    sha1_transform_vector (w0_t, w1_t, w2_t, w3_t, digest);

    // iterations

    for (u32 i = 0; i < salt_iter; i++)
    {
      w0_t[0] = digest[0];
      w0_t[1] = digest[1];
      w0_t[2] = digest[2];
      w0_t[3] = digest[3];
      w1_t[0] = digest[4];
      w1_t[1] = salt_buf0[0];
      w1_t[2] = salt_buf0[1];
      w1_t[3] = salt_buf0[2];
      w2_t[0] = salt_buf0[3];
      w2_t[1] = salt_buf1[0];
      w2_t[2] = salt_buf1[1];
      w2_t[3] = salt_buf1[2];
      w3_t[0] = salt_buf1[3];
      w3_t[1] = 0;
      w3_t[2] = 0;
      w3_t[3] = (20 + salt_len) * 8;

      digest[0] = SHA1M_A;
      digest[1] = SHA1M_B;
      digest[2] = SHA1M_C;
      digest[3] = SHA1M_D;
      digest[4] = SHA1M_E;

      sha1_transform_vector (w0_t, w1_t, w2_t, w3_t, digest);
    }

    COMPARE_M_SIMD (digest[3], digest[4], digest[2], digest[1]);
  }
}

DECLSPEC void m08300s (PRIVATE_AS u32 *w0, PRIVATE_AS u32 *w1, PRIVATE_AS u32 *w2, PRIVATE_AS u32 *w3, const u32 pw_len, KERN_ATTR_FUNC_BASIC ())
{
  /**
   * modifiers are taken from args
   */

  /**
   * salt
   */

  const u32 salt_iter = salt_bufs[SALT_POS_HOST].salt_iter;

  u32 salt_buf0[4];
  u32 salt_buf1[4];

  salt_buf0[0] = hc_swap32_S (salt_bufs[SALT_POS_HOST].salt_buf[ 0]);
  salt_buf0[1] = hc_swap32_S (salt_bufs[SALT_POS_HOST].salt_buf[ 1]);
  salt_buf0[2] = hc_swap32_S (salt_bufs[SALT_POS_HOST].salt_buf[ 2]);
  salt_buf0[3] = hc_swap32_S (salt_bufs[SALT_POS_HOST].salt_buf[ 3]);
  salt_buf1[0] = hc_swap32_S (salt_bufs[SALT_POS_HOST].salt_buf[ 4]);
  salt_buf1[1] = hc_swap32_S (salt_bufs[SALT_POS_HOST].salt_buf[ 5]);
  salt_buf1[2] = hc_swap32_S (salt_bufs[SALT_POS_HOST].salt_buf[ 6]);
  salt_buf1[3] = hc_swap32_S (salt_bufs[SALT_POS_HOST].salt_buf[ 7]);

  const u32 salt_len = salt_bufs[SALT_POS_HOST].salt_len;

  u32 domain_buf0[4];
  u32 domain_buf1[4];

  domain_buf0[0] = hc_swap32_S (salt_bufs[SALT_POS_HOST].salt_buf_pc[ 0]);
  domain_buf0[1] = hc_swap32_S (salt_bufs[SALT_POS_HOST].salt_buf_pc[ 1]);
  domain_buf0[2] = hc_swap32_S (salt_bufs[SALT_POS_HOST].salt_buf_pc[ 2]);
  domain_buf0[3] = hc_swap32_S (salt_bufs[SALT_POS_HOST].salt_buf_pc[ 3]);
  domain_buf1[0] = hc_swap32_S (salt_bufs[SALT_POS_HOST].salt_buf_pc[ 4]);
  domain_buf1[1] = hc_swap32_S (salt_bufs[SALT_POS_HOST].salt_buf_pc[ 5]);
  domain_buf1[2] = hc_swap32_S (salt_bufs[SALT_POS_HOST].salt_buf_pc[ 6]);
  domain_buf1[3] = 0;

  const u32 domain_len = salt_bufs[SALT_POS_HOST].salt_len_pc;

  u32 s0[4];
  u32 s1[4];
  u32 s2[4];
  u32 s3[4];

  s0[0] = domain_buf0[0];
  s0[1] = domain_buf0[1];
  s0[2] = domain_buf0[2];
  s0[3] = domain_buf0[3];
  s1[0] = domain_buf1[0];
  s1[1] = domain_buf1[1];
  s1[2] = domain_buf1[2];
  s1[3] = domain_buf1[3];
  s2[0] = 0;
  s2[1] = 0;
  s2[2] = 0;
  s2[3] = 0;
  s3[0] = 0;
  s3[1] = 0;
  s3[2] = 0;
  s3[3] = 0;

  switch_buffer_by_offset_be_S (s0, s1, s2, s3, pw_len);

  w0[0] |= s0[0];
  w0[1] |= s0[1];
  w0[2] |= s0[2];
  w0[3] |= s0[3];
  w1[0] |= s1[0];
  w1[1] |= s1[1];
  w1[2] |= s1[2];
  w1[3] |= s1[3];
  w2[0] |= s2[0];
  w2[1] |= s2[1];
  w2[2] |= s2[2];
  w2[3] |= s2[3];
  w3[0] |= s3[0];
  w3[1] |= s3[1];
  w3[2] |= s3[2];
  w3[3] |= s3[3];

  s0[0] = salt_buf0[0];
  s0[1] = salt_buf0[1];
  s0[2] = salt_buf0[2];
  s0[3] = salt_buf0[3];
  s1[0] = salt_buf1[0];
  s1[1] = salt_buf1[1];
  s1[2] = salt_buf1[2];
  s1[3] = salt_buf1[3];
  s2[0] = 0;
  s2[1] = 0;
  s2[2] = 0;
  s2[3] = 0;
  s3[0] = 0;
  s3[1] = 0;
  s3[2] = 0;
  s3[3] = 0;

  switch_buffer_by_offset_be_S (s0, s1, s2, s3, pw_len + domain_len + 1);

  w0[0] |= s0[0];
  w0[1] |= s0[1];
  w0[2] |= s0[2];
  w0[3] |= s0[3];
  w1[0] |= s1[0];
  w1[1] |= s1[1];
  w1[2] |= s1[2];
  w1[3] |= s1[3];
  w2[0] |= s2[0];
  w2[1] |= s2[1];
  w2[2] |= s2[2];
  w2[3] |= s2[3];
  w3[0] |= s3[0];
  w3[1] |= s3[1];
  w3[2] |= s3[2];
  w3[3] |= s3[3];

  /**
   * digest
   */

  const u32 search[4] =
  {
    digests_buf[DIGESTS_OFFSET_HOST].digest_buf[DGST_R0],
    digests_buf[DIGESTS_OFFSET_HOST].digest_buf[DGST_R1],
    digests_buf[DIGESTS_OFFSET_HOST].digest_buf[DGST_R2],
    digests_buf[DIGESTS_OFFSET_HOST].digest_buf[DGST_R3]
  };

  /**
   * loop
   */

  u32 w0l = w0[0];

  for (u32 il_pos = 0; il_pos < IL_CNT; il_pos += VECT_SIZE)
  {
    const u32x w0r = ix_create_bft (bfs_buf, il_pos);

    const u32x w0lr = w0l | w0r;

    u32x w0_t[4];
    u32x w1_t[4];
    u32x w2_t[4];
    u32x w3_t[4];

    w0_t[0] = w0lr;
    w0_t[1] = w0[1];
    w0_t[2] = w0[2];
    w0_t[3] = w0[3];
    w1_t[0] = w1[0];
    w1_t[1] = w1[1];
    w1_t[2] = w1[2];
    w1_t[3] = w1[3];
    w2_t[0] = w2[0];
    w2_t[1] = w2[1];
    w2_t[2] = w2[2];
    w2_t[3] = w2[3];
    w3_t[0] = w3[0];
    w3_t[1] = w3[1];
    w3_t[2] = w3[2];
    w3_t[3] = w3[3];

    // replace "." with the length:

    #if VECT_SIZE == 1
      const u32 len = replace_dot_by_len (w0_t, w1_t, w2_t, w3_t, pw_len);

      switch_buffer_by_offset_be (w0_t, w1_t, w2_t, w3_t, 1);

      w0_t[0] |= (len & 0xff) << 24;
    #endif
    #if VECT_SIZE >= 2
      REPLACE_DOT_BY_LEN_VECT (0)
      REPLACE_DOT_BY_LEN_VECT (1)
    #endif
    #if VECT_SIZE >= 4
      REPLACE_DOT_BY_LEN_VECT (2)
      REPLACE_DOT_BY_LEN_VECT (3)
    #endif
    #if VECT_SIZE >= 8
      REPLACE_DOT_BY_LEN_VECT (4)
      REPLACE_DOT_BY_LEN_VECT (5)
      REPLACE_DOT_BY_LEN_VECT (6)
      REPLACE_DOT_BY_LEN_VECT (7)
    #endif
    #if VECT_SIZE >= 16
      REPLACE_DOT_BY_LEN_VECT (8)
      REPLACE_DOT_BY_LEN_VECT (9)
      REPLACE_DOT_BY_LEN_VECT (a)
      REPLACE_DOT_BY_LEN_VECT (b)
      REPLACE_DOT_BY_LEN_VECT (c)
      REPLACE_DOT_BY_LEN_VECT (d)
      REPLACE_DOT_BY_LEN_VECT (e)
      REPLACE_DOT_BY_LEN_VECT (f)
    #endif

    w3_t[2]  = 0;
    w3_t[3]  = (1 + pw_len + domain_len + 1 + salt_len) * 8;

    /**
     * sha1
     */

    u32x digest[5];

    digest[0] = SHA1M_A;
    digest[1] = SHA1M_B;
    digest[2] = SHA1M_C;
    digest[3] = SHA1M_D;
    digest[4] = SHA1M_E;

    sha1_transform_vector (w0_t, w1_t, w2_t, w3_t, digest);

    // iterations

    for (u32 i = 0; i < salt_iter; i++)
    {
      w0_t[0] = digest[0];
      w0_t[1] = digest[1];
      w0_t[2] = digest[2];
      w0_t[3] = digest[3];
      w1_t[0] = digest[4];
      w1_t[1] = salt_buf0[0];
      w1_t[2] = salt_buf0[1];
      w1_t[3] = salt_buf0[2];
      w2_t[0] = salt_buf0[3];
      w2_t[1] = salt_buf1[0];
      w2_t[2] = salt_buf1[1];
      w2_t[3] = salt_buf1[2];
      w3_t[0] = salt_buf1[3];
      w3_t[1] = 0;
      w3_t[2] = 0;
      w3_t[3] = (20 + salt_len) * 8;

      digest[0] = SHA1M_A;
      digest[1] = SHA1M_B;
      digest[2] = SHA1M_C;
      digest[3] = SHA1M_D;
      digest[4] = SHA1M_E;

      sha1_transform_vector (w0_t, w1_t, w2_t, w3_t, digest);
    }

    COMPARE_S_SIMD (digest[3], digest[4], digest[2], digest[1]);
  }
}

KERNEL_FQ KERNEL_FA void m08300_m04 (KERN_ATTR_BASIC ())
{
  /**
   * base
   */

  const u64 lid = get_local_id (0);
  const u64 gid = get_global_id (0);
  const u64 lsz = get_local_size (0);

  if (gid >= GID_CNT) return;

  u32 w0[4];

  w0[0] = pws[gid].i[ 0];
  w0[1] = pws[gid].i[ 1];
  w0[2] = pws[gid].i[ 2];
  w0[3] = pws[gid].i[ 3];

  u32 w1[4];

  w1[0] = 0;
  w1[1] = 0;
  w1[2] = 0;
  w1[3] = 0;

  u32 w2[4];

  w2[0] = 0;
  w2[1] = 0;
  w2[2] = 0;
  w2[3] = 0;

  u32 w3[4];

  w3[0] = 0;
  w3[1] = 0;
  w3[2] = 0;
  w3[3] = 0;

  const u32 pw_len = pws[gid].pw_len & 63;

  /**
   * main
   */

  m08300m (w0, w1, w2, w3, pw_len, pws, rules_buf, combs_buf, bfs_buf, tmps, hooks, bitmaps_buf_s1_a, bitmaps_buf_s1_b, bitmaps_buf_s1_c, bitmaps_buf_s1_d, bitmaps_buf_s2_a, bitmaps_buf_s2_b, bitmaps_buf_s2_c, bitmaps_buf_s2_d, plains_buf, digests_buf, hashes_shown, salt_bufs, esalt_bufs, d_return_buf, d_extra0_buf, d_extra1_buf, d_extra2_buf, d_extra3_buf, kernel_param, gid, lid, lsz);
}

KERNEL_FQ KERNEL_FA void m08300_m08 (KERN_ATTR_BASIC ())
{
  /**
   * base
   */

  const u64 lid = get_local_id (0);
  const u64 gid = get_global_id (0);
  const u64 lsz = get_local_size (0);

  if (gid >= GID_CNT) return;

  u32 w0[4];

  w0[0] = pws[gid].i[ 0];
  w0[1] = pws[gid].i[ 1];
  w0[2] = pws[gid].i[ 2];
  w0[3] = pws[gid].i[ 3];

  u32 w1[4];

  w1[0] = pws[gid].i[ 4];
  w1[1] = pws[gid].i[ 5];
  w1[2] = pws[gid].i[ 6];
  w1[3] = pws[gid].i[ 7];

  u32 w2[4];

  w2[0] = 0;
  w2[1] = 0;
  w2[2] = 0;
  w2[3] = 0;

  u32 w3[4];

  w3[0] = 0;
  w3[1] = 0;
  w3[2] = 0;
  w3[3] = 0;

  const u32 pw_len = pws[gid].pw_len & 63;

  /**
   * main
   */

  m08300m (w0, w1, w2, w3, pw_len, pws, rules_buf, combs_buf, bfs_buf, tmps, hooks, bitmaps_buf_s1_a, bitmaps_buf_s1_b, bitmaps_buf_s1_c, bitmaps_buf_s1_d, bitmaps_buf_s2_a, bitmaps_buf_s2_b, bitmaps_buf_s2_c, bitmaps_buf_s2_d, plains_buf, digests_buf, hashes_shown, salt_bufs, esalt_bufs, d_return_buf, d_extra0_buf, d_extra1_buf, d_extra2_buf, d_extra3_buf, kernel_param, gid, lid, lsz);
}

KERNEL_FQ KERNEL_FA void m08300_m16 (KERN_ATTR_BASIC ())
{
  /**
   * base
   */

  const u64 lid = get_local_id (0);
  const u64 gid = get_global_id (0);
  const u64 lsz = get_local_size (0);

  if (gid >= GID_CNT) return;

  u32 w0[4];

  w0[0] = pws[gid].i[ 0];
  w0[1] = pws[gid].i[ 1];
  w0[2] = pws[gid].i[ 2];
  w0[3] = pws[gid].i[ 3];

  u32 w1[4];

  w1[0] = pws[gid].i[ 4];
  w1[1] = pws[gid].i[ 5];
  w1[2] = pws[gid].i[ 6];
  w1[3] = pws[gid].i[ 7];

  u32 w2[4];

  w2[0] = pws[gid].i[ 8];
  w2[1] = pws[gid].i[ 9];
  w2[2] = pws[gid].i[10];
  w2[3] = pws[gid].i[11];

  u32 w3[4];

  w3[0] = pws[gid].i[12];
  w3[1] = pws[gid].i[13];
  w3[2] = 0;
  w3[3] = 0;

  const u32 pw_len = pws[gid].pw_len & 63;

  /**
   * main
   */

  m08300m (w0, w1, w2, w3, pw_len, pws, rules_buf, combs_buf, bfs_buf, tmps, hooks, bitmaps_buf_s1_a, bitmaps_buf_s1_b, bitmaps_buf_s1_c, bitmaps_buf_s1_d, bitmaps_buf_s2_a, bitmaps_buf_s2_b, bitmaps_buf_s2_c, bitmaps_buf_s2_d, plains_buf, digests_buf, hashes_shown, salt_bufs, esalt_bufs, d_return_buf, d_extra0_buf, d_extra1_buf, d_extra2_buf, d_extra3_buf, kernel_param, gid, lid, lsz);
}

KERNEL_FQ KERNEL_FA void m08300_s04 (KERN_ATTR_BASIC ())
{
  /**
   * base
   */

  const u64 lid = get_local_id (0);
  const u64 gid = get_global_id (0);
  const u64 lsz = get_local_size (0);

  if (gid >= GID_CNT) return;

  u32 w0[4];

  w0[0] = pws[gid].i[ 0];
  w0[1] = pws[gid].i[ 1];
  w0[2] = pws[gid].i[ 2];
  w0[3] = pws[gid].i[ 3];

  u32 w1[4];

  w1[0] = 0;
  w1[1] = 0;
  w1[2] = 0;
  w1[3] = 0;

  u32 w2[4];

  w2[0] = 0;
  w2[1] = 0;
  w2[2] = 0;
  w2[3] = 0;

  u32 w3[4];

  w3[0] = 0;
  w3[1] = 0;
  w3[2] = 0;
  w3[3] = 0;

  const u32 pw_len = pws[gid].pw_len & 63;

  /**
   * main
   */

  m08300s (w0, w1, w2, w3, pw_len, pws, rules_buf, combs_buf, bfs_buf, tmps, hooks, bitmaps_buf_s1_a, bitmaps_buf_s1_b, bitmaps_buf_s1_c, bitmaps_buf_s1_d, bitmaps_buf_s2_a, bitmaps_buf_s2_b, bitmaps_buf_s2_c, bitmaps_buf_s2_d, plains_buf, digests_buf, hashes_shown, salt_bufs, esalt_bufs, d_return_buf, d_extra0_buf, d_extra1_buf, d_extra2_buf, d_extra3_buf, kernel_param, gid, lid, lsz);
}

KERNEL_FQ KERNEL_FA void m08300_s08 (KERN_ATTR_BASIC ())
{
  /**
   * base
   */

  const u64 lid = get_local_id (0);
  const u64 gid = get_global_id (0);
  const u64 lsz = get_local_size (0);

  if (gid >= GID_CNT) return;

  u32 w0[4];

  w0[0] = pws[gid].i[ 0];
  w0[1] = pws[gid].i[ 1];
  w0[2] = pws[gid].i[ 2];
  w0[3] = pws[gid].i[ 3];

  u32 w1[4];

  w1[0] = pws[gid].i[ 4];
  w1[1] = pws[gid].i[ 5];
  w1[2] = pws[gid].i[ 6];
  w1[3] = pws[gid].i[ 7];

  u32 w2[4];

  w2[0] = 0;
  w2[1] = 0;
  w2[2] = 0;
  w2[3] = 0;

  u32 w3[4];

  w3[0] = 0;
  w3[1] = 0;
  w3[2] = 0;
  w3[3] = 0;

  const u32 pw_len = pws[gid].pw_len & 63;

  /**
   * main
   */

  m08300s (w0, w1, w2, w3, pw_len, pws, rules_buf, combs_buf, bfs_buf, tmps, hooks, bitmaps_buf_s1_a, bitmaps_buf_s1_b, bitmaps_buf_s1_c, bitmaps_buf_s1_d, bitmaps_buf_s2_a, bitmaps_buf_s2_b, bitmaps_buf_s2_c, bitmaps_buf_s2_d, plains_buf, digests_buf, hashes_shown, salt_bufs, esalt_bufs, d_return_buf, d_extra0_buf, d_extra1_buf, d_extra2_buf, d_extra3_buf, kernel_param, gid, lid, lsz);
}

KERNEL_FQ KERNEL_FA void m08300_s16 (KERN_ATTR_BASIC ())
{
  /**
   * base
   */

  const u64 lid = get_local_id (0);
  const u64 gid = get_global_id (0);
  const u64 lsz = get_local_size (0);

  if (gid >= GID_CNT) return;

  u32 w0[4];

  w0[0] = pws[gid].i[ 0];
  w0[1] = pws[gid].i[ 1];
  w0[2] = pws[gid].i[ 2];
  w0[3] = pws[gid].i[ 3];

  u32 w1[4];

  w1[0] = pws[gid].i[ 4];
  w1[1] = pws[gid].i[ 5];
  w1[2] = pws[gid].i[ 6];
  w1[3] = pws[gid].i[ 7];

  u32 w2[4];

  w2[0] = pws[gid].i[ 8];
  w2[1] = pws[gid].i[ 9];
  w2[2] = pws[gid].i[10];
  w2[3] = pws[gid].i[11];

  u32 w3[4];

  w3[0] = pws[gid].i[12];
  w3[1] = pws[gid].i[13];
  w3[2] = 0;
  w3[3] = 0;

  const u32 pw_len = pws[gid].pw_len & 63;

  /**
   * main
   */

  m08300s (w0, w1, w2, w3, pw_len, pws, rules_buf, combs_buf, bfs_buf, tmps, hooks, bitmaps_buf_s1_a, bitmaps_buf_s1_b, bitmaps_buf_s1_c, bitmaps_buf_s1_d, bitmaps_buf_s2_a, bitmaps_buf_s2_b, bitmaps_buf_s2_c, bitmaps_buf_s2_d, plains_buf, digests_buf, hashes_shown, salt_bufs, esalt_bufs, d_return_buf, d_extra0_buf, d_extra1_buf, d_extra2_buf, d_extra3_buf, kernel_param, gid, lid, lsz);
}

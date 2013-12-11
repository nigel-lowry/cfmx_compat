require 'encoding_factory'

class Worker
  @@M_MASK_A = 0x80000062
  @@M_MASK_B = 0x40000020
  @@M_MASK_C = 0x10000002
  @@M_ROT0_A = 0x7fffffff
  @@M_ROT0_B = 0x3fffffff
  @@M_ROT0_C = 0xfffffff
  @@M_ROT1_A = 0x80000000
  @@M_ROT1_B = 0xc0000000
  @@M_ROT1_C = 0xf0000000

  @@UNSIGNED_CHAR = 'C*'

  def initialize encoding, key
    raise ArgumentError, "CfmxCompat a key must be specified for encryption or decryption" if key.nil? or key.empty?

    @encoder = EncodingFactory.new.create(encoding)
    @key = key
  end

  def encrypt(plaintext)
    encode(transform_string(plaintext || ''))
  end

  def decrypt(ciphertext)
    transform_string(decode(ciphertext || ''))
  end

  private

  def encode(result)
    @encoder.encode(result)
  end

  def decode(encoded)
    @encoder.decode(encoded)
  end

  def transform_string(string)
    @m_LFSR_A = 0x13579bdf
    @m_LFSR_B = 0x2468ace0
    @m_LFSR_C = 0xfdb97531
    seed_from_key

    string.bytes.map {|byte| transform_byte(byte) }.pack(@@UNSIGNED_CHAR)
  end

  def seed_from_key
    doublekey = (@key * 2).bytes.to_a
    seed = Array.new(12) {|i| doublekey[i] || 0 }

    4.times do |i|
      @m_LFSR_A = munge1 @m_LFSR_A, seed[i + 4]
      @m_LFSR_B = munge1 @m_LFSR_B, seed[i + 4]
      @m_LFSR_C = munge1 @m_LFSR_C, seed[i + 4]
    end

    @m_LFSR_A = 0x13579bdf if @m_LFSR_A.zero?
    @m_LFSR_B = 0x2468ace0 if @m_LFSR_B.zero?
    @m_LFSR_C = 0xfdb97531 if @m_LFSR_C.zero?
  end

  def munge1 x, y
    (x << 8) | y
  end

  def transform_byte(target)
    crypto = 0
    b = @m_LFSR_B & 1
    c = @m_LFSR_C & 1

    8.times do
      if @m_LFSR_A & 1 == 0
        @m_LFSR_A = munge2 @m_LFSR_A, @@M_ROT0_A

        if @m_LFSR_C & 1 == 0
          @m_LFSR_C = munge2 @m_LFSR_C, @@M_ROT0_C
          c = 0
        else
          @m_LFSR_C = munge3 @m_LFSR_C, @@M_MASK_C, @@M_ROT1_C
          c = 1
        end
      else
        @m_LFSR_A = munge3 @m_LFSR_A, @@M_MASK_A, @@M_ROT1_A

        if @m_LFSR_B & 1 == 0
          @m_LFSR_B = munge2 @m_LFSR_B, @@M_ROT0_B
          b = 0
        else
          @m_LFSR_B = munge3 @m_LFSR_B, @@M_MASK_B, @@M_ROT1_B
          b = 1
        end
      end
      crypto = crypto << 1 | b ^ c
    end
    target ^ crypto
  end

  def munge2 x, y
    x >> 1 & y
  end

  def munge3 x, y, z
    x ^ y >> 1 | z
  end

end
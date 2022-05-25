#pragma once

#include <cstddef>
#include <optional>

#include <xassert/XAssert.h>
#include <xutils/Log.h>

namespace libutt {
class Coin;
class Params;
class BurnOp;
class RandSigPK;
class RegAuthPK;

std::ostream& operator<<(std::ostream&, const libutt::BurnOp&);
std::istream& operator>>(std::istream&, libutt::BurnOp&);

// Represents an operation that burns a valid coin. This operation should be
// part of a public transaction (e.g., a transaction that converts an anonymous
// coin to public money).
// This operation reveals the owner and the value of the coin.
class BurnOp {
 protected:
  // Pointer to the internal data of the object
  // (We decided to hide the details because we plan to change them later)
  void* p = nullptr;

 public:
  BurnOp(const Params& p, const AddrSK& ask, const Coin& coin, const RandSigPK& bpk, const RegAuthPK& rpk);

  BurnOp(std::istream& in);

  BurnOp(const BurnOp& o);

  virtual ~BurnOp();

  BurnOp& operator=(const BurnOp& o);

  size_t getSize() const;

  bool validate(const Params& p, const RandSigPK& bpk, const RegAuthPK& rpk) const;

  size_t getValue() const;

  std::string getOwnerPid() const;

  std::string getNullifier() const;

  std::string getHashHex() const;

  bool operator==(const BurnOp& o) const;
  bool operator!=(const BurnOp& o) const { return !operator==(o); }

  friend std::ostream& operator<<(std::ostream&, const libutt::BurnOp&);
  friend std::istream& operator>>(std::istream&, libutt::BurnOp&);
};

}  // end of namespace libutt
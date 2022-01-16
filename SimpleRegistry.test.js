const { ethers } = require('hardhat');
const { expect } = require('chai');
const { BigNumber } = require('ethers');

describe('SimpleRegistry', () => {
  let registry;

  before(async () => {
    const Registry = await ethers.getContractFactory('SimpleRegistry');
    registry = await Registry.deploy();
  });

  describe('getPrice', () => {
    it('should revert getPrice when name len less than 3', async () => {
      await expect(registry.getPrice('a')).to.be.revertedWith(
        'Name length must be greater than 2',
      );
    });

    it('should return 0.01 ETH price for name longer than 10 chars', async () => {
      expect(await registry.getPrice('qwertyuiopa')).to.be.equal(ethers.utils.parseEther('0.01'));
    });

    it('should return 0.02 ETH price for name 9 chars long', async () => {
      expect(await registry.getPrice('qwertyuio')).to.be.equal(ethers.utils.parseEther('0.02'));
    });

    it('should return 0.03 ETH price for name 9 chars long', async () => {
      expect(await registry.getPrice('qwertyui')).to.be.equal(ethers.utils.parseEther('0.03'));
    });

    it('should return 0.06 ETH price for name 5 chars long', async () => {
      expect(await registry.getPrice('qwert')).to.be.equal(ethers.utils.parseEther('0.06'));
    });

    it('should return 0.08 ETH price for name 3 chars long', async () => {
      expect(await registry.getPrice('qwe')).to.be.equal(ethers.utils.parseEther('0.08'));
    });
  });

  it('should pass sunny flow', async () => {
    const [sender] = await ethers.getSigners();
    const salt = ethers.utils.id('qwerty');
    const name = 'test';
    await expect(registry.getOwner(name)).to.be.revertedWith(
      'Name does not exists or expired',
    );

    const commitment = await registry.buildCommitment(name, sender.address, salt);
    await registry.commit(commitment);
    await expect(registry.getOwner(name)).to.be.revertedWith(
      'Name does not exists or expired',
    );

    const price = await registry.getPrice(name);
    await registry.register(name, sender.address, salt, { value: BigNumber.from(price) });
    expect(await registry.getOwner(name)).to.be.eq(sender.address);

    await registry.renew(name, { value: BigNumber.from(price) });
    expect(await registry.getOwner(name)).to.be.eq(sender.address);
  });
});

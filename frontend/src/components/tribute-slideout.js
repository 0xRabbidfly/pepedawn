// Tribute Slideout Component
// Global floating tab that opens a slideout with Fake Rare community tribute

export function initTributeSlideout() {
  // Create the floating tab button
  const floatingTab = document.createElement('button');
  floatingTab.id = 'tribute-tab';
  floatingTab.className = 'tribute-floating-tab';
  floatingTab.setAttribute('aria-label', 'Open Fake Rare Community Tribute');
  floatingTab.innerHTML = `
    <img src="/logo-icon.png" alt="PEPEDAWN Logo" class="tribute-tab-icon" />
  `;
  
  // Create the slideout panel
  const slideout = document.createElement('div');
  slideout.id = 'tribute-slideout';
  slideout.className = 'tribute-slideout';
  slideout.innerHTML = `
    <div class="tribute-slideout-content">
      <button class="tribute-close-btn" id="tribute-close" aria-label="Close tribute panel">×</button>
      
      <div class="tribute-header">
        <img src="/logo-icon.png" alt="PEPEDAWN Logo" class="tribute-logo" />
        <h2>🐸 A Tribute to the Fake Rare Community</h2>
      </div>
      
      <div class="tribute-body">
        <p><strong>PEPEDAWN exists because of the legendary Fake Rare Pepe community.</strong></p>
        
        <p>While the original Rare Pepe collection captured lightning in a bottle on the Bitcoin blockchain via Counterparty, the <strong>Fake Rare</strong> movement emerged as a brilliant satire—an artistic rebellion that questioned authenticity, value, and what makes art "real" in the first place.</p>
        
        <div class="tribute-highlight">
          <p><strong>🎨 The Fake Rare Ethos</strong></p>
          <p>Fake Rares are not counterfeits—they're commentary. They're art about art. They celebrate the absurdity of digital scarcity while simultaneously participating in it. They ask: if a meme is copied, remixed, and reborn on the blockchain, is it any less "real" than the original?</p>
        </div>
        
        <p><strong>This project distributes 133 Fake Rare Pepe cards</strong> minted on Counterparty/Bitcoin, honoring the OG Fake Rare spirit: provably scarce, verifiably random, undeniably memetic.</p>
        
        <div class="tribute-links">
          <p><strong>Explore the Fake Rare Universe:</strong></p>
          <ul>
            <li>🌐 <a href="https://pepe.wtf" target="_blank" rel="noopener noreferrer">pepe.wtf</a> - The definitive Fake Rare directory</li>
            <li>𝕏 Follow <a href="https://twitter.com/fakerares_xcp" target="_blank" rel="noopener noreferrer">@fakerares_xcp</a> on X/Twitter</li>
            <li>🔗 Traded on Counterparty (XCP) - Bitcoin's OG NFT protocol</li>
          </ul>
        </div>
        
        <div class="tribute-footer">
          <p><em>"In a world of expensive JPEGs, Fake Rares remind us that the real treasure is the memes we made along the way."</em></p>
          <p><strong>— The Fake Rare Manifesto (probably)</strong></p>
        </div>
      </div>
    </div>
  `;
  
  // Append to body
  document.body.appendChild(floatingTab);
  document.body.appendChild(slideout);
  
  // Event listeners
  floatingTab.addEventListener('click', () => {
    slideout.classList.add('open');
  });
  
  const closeBtn = document.getElementById('tribute-close');
  closeBtn.addEventListener('click', () => {
    slideout.classList.remove('open');
  });
  
  // Close on backdrop click
  slideout.addEventListener('click', (e) => {
    if (e.target === slideout) {
      slideout.classList.remove('open');
    }
  });
  
  // Close on escape key
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && slideout.classList.contains('open')) {
      slideout.classList.remove('open');
    }
  });
}


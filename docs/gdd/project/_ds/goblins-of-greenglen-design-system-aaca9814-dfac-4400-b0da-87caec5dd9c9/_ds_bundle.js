/* @ds-bundle: {"format":4,"namespace":"GoblinsOfGreenglenDesignSystem_aaca98","components":[{"name":"TierBadge","sourcePath":"components/badges/TierBadge.jsx"},{"name":"GreenglenButton","sourcePath":"components/core/GreenglenButton.jsx"},{"name":"GreenglenHeading","sourcePath":"components/core/GreenglenHeading.jsx"},{"name":"HeartsMeter","sourcePath":"components/hud/HeartsMeter.jsx"},{"name":"StatValue","sourcePath":"components/hud/StatValue.jsx"},{"name":"SubmenuShell","sourcePath":"components/navigation/SubmenuShell.jsx"}],"sourceHashes":{"components/badges/TierBadge.jsx":"604b42c45b7e","components/core/GreenglenButton.jsx":"1068dc37e956","components/core/GreenglenHeading.jsx":"589928789185","components/hud/HeartsMeter.jsx":"33d19fc015b5","components/hud/StatValue.jsx":"e1f492e54791","components/navigation/SubmenuShell.jsx":"2893762e2344","ui_kits/main-menu/App.jsx":"b7a78fb32f3e","ui_kits/main-menu/MainMenu.jsx":"fb27ede88ec8","ui_kits/main-menu/MapScreen.jsx":"599e6445b723","ui_kits/main-menu/ResultScreen.jsx":"94e6d43437a5","ui_kits/main-menu/SkinsScreen.jsx":"cff8ae01bdb5"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.GoblinsOfGreenglenDesignSystem_aaca98 = window.GoblinsOfGreenglenDesignSystem_aaca98 || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/badges/TierBadge.jsx
try { (() => {
const COLORS = {
  rare: "var(--rare)",
  epic: "var(--epic)",
  legendary: "var(--legendary)",
  starter: "var(--starter)",
  default: "var(--default-tier)"
};
function TierBadge({
  tier = "default",
  label
}) {
  const color = COLORS[tier] || COLORS.default;
  return /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-body)",
      fontWeight: 600,
      fontSize: 16,
      color,
      textTransform: "capitalize"
    }
  }, label || tier);
}
Object.assign(__ds_scope, { TierBadge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/badges/TierBadge.jsx", error: String((e && e.message) || e) }); }

// components/core/GreenglenButton.jsx
try { (() => {
const TEX = {
  normal: "../../assets/ui/buttons/button_greenglen_normal.png",
  hover: "../../assets/ui/buttons/button_greenglen_hover.png",
  pressed: "../../assets/ui/buttons/button_greenglen_pressed.png",
  disabled: "../../assets/ui/buttons/button_greenglen_disabled.png"
};
function GreenglenButton({
  label,
  height = 44,
  disabled = false,
  onClick,
  style
}) {
  const [state, setState] = React.useState("normal");
  const bg = disabled ? TEX.disabled : TEX[state];
  const textColor = disabled ? "var(--text-disabled)" : state === "pressed" ? "var(--text-pressed)" : state === "hover" ? "var(--text-hover)" : "var(--text-body)";
  return /*#__PURE__*/React.createElement("button", {
    disabled: disabled,
    onClick: onClick,
    onMouseEnter: () => !disabled && setState("hover"),
    onMouseLeave: () => !disabled && setState("normal"),
    onMouseDown: () => !disabled && setState("pressed"),
    onMouseUp: () => !disabled && setState("hover"),
    style: {
      height,
      width: height * 6,
      backgroundImage: `url(${bg})`,
      backgroundSize: "100% 100%",
      backgroundRepeat: "no-repeat",
      border: "none",
      cursor: disabled ? "default" : "pointer",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      padding: "6px 32px",
      fontFamily: "var(--font-body)",
      fontWeight: 600,
      fontSize: "var(--fs-button)",
      color: textColor,
      WebkitTextStroke: "1px var(--text-outline)",
      textShadow: "0 0 3px var(--text-outline), 0 0 3px var(--text-outline)",
      letterSpacing: "0.02em",
      ...style
    }
  }, label);
}
Object.assign(__ds_scope, { GreenglenButton });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/GreenglenButton.jsx", error: String((e && e.message) || e) }); }

// components/core/GreenglenHeading.jsx
try { (() => {
function GreenglenHeading({
  text,
  size = 32,
  align = "center",
  accent,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-display)",
      fontWeight: 700,
      fontSize: size,
      lineHeight: "var(--lh-tight)",
      textAlign: align,
      color: accent || "var(--text-heading)",
      WebkitTextStroke: `${Math.max(3, Math.round(size / 8))}px var(--text-outline)`,
      paintOrder: "stroke fill",
      ...style
    }
  }, text);
}
Object.assign(__ds_scope, { GreenglenHeading });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/GreenglenHeading.jsx", error: String((e && e.message) || e) }); }

// components/hud/HeartsMeter.jsx
try { (() => {
function HeartsMeter({
  health,
  maxHealth = 3,
  size = 22
}) {
  return /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: size,
      color: "#fff",
      textShadow: "0 0 4px #000, 0 0 4px #000",
      fontFamily: "var(--font-body)"
    }
  }, Array.from({
    length: maxHealth
  }, (_, i) => i < health ? "♥ " : "♡ "));
}
Object.assign(__ds_scope, { HeartsMeter });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/hud/HeartsMeter.jsx", error: String((e && e.message) || e) }); }

// components/hud/StatValue.jsx
try { (() => {
function StatValue({
  caption,
  value,
  color = "var(--text-body)"
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      gap: 2,
      minWidth: 150
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-body)",
      fontSize: 15,
      color: "#B8C2B8"
    }
  }, caption), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-display)",
      fontWeight: 700,
      fontSize: 34,
      color,
      WebkitTextStroke: "2px var(--text-outline)",
      paintOrder: "stroke fill"
    }
  }, value));
}
Object.assign(__ds_scope, { StatValue });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/hud/StatValue.jsx", error: String((e && e.message) || e) }); }

// components/navigation/SubmenuShell.jsx
try { (() => {
const BGS = {
  quests: "../../assets/backgrounds/menu_bg_quests.png",
  cases: "../../assets/backgrounds/menu_bg_cases.png",
  skins: "../../assets/backgrounds/menu_bg_skins.png",
  map: "../../assets/backgrounds/menu_bg_map.png"
};
function SubmenuShell({
  title,
  background = "quests",
  children,
  dim = 0.55
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      width: "100%",
      height: "100%",
      overflow: "hidden",
      fontFamily: "var(--font-body)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      backgroundImage: `url(${BGS[background] || BGS.quests})`,
      backgroundSize: "cover",
      backgroundPosition: "center"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      background: `rgba(13,15,26,${dim})`
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      zIndex: 1,
      padding: "24px 32px",
      display: "flex",
      flexDirection: "column",
      gap: 14,
      height: "100%",
      boxSizing: "border-box"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-display)",
      fontWeight: 700,
      fontSize: 32,
      textAlign: "center",
      color: "var(--cream)",
      WebkitTextStroke: "5px var(--brown-ink)",
      paintOrder: "stroke fill"
    }
  }, title), children));
}
Object.assign(__ds_scope, { SubmenuShell });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/SubmenuShell.jsx", error: String((e && e.message) || e) }); }

// ui_kits/main-menu/App.jsx
try { (() => {
const {
  useState
} = React;
function App() {
  const [screen, setScreen] = useState("menu");
  if (screen === "skins") return /*#__PURE__*/React.createElement(SkinsScreen, {
    onBack: () => setScreen("menu")
  });
  if (screen === "map") return /*#__PURE__*/React.createElement(MapScreen, {
    onBack: () => setScreen("menu")
  });
  if (screen === "result") return /*#__PURE__*/React.createElement(ResultScreen, {
    onMainMenu: () => setScreen("menu")
  });
  return /*#__PURE__*/React.createElement(MainMenu, {
    onNav: setScreen
  });
}
ReactDOM.createRoot(document.getElementById("root")).render(/*#__PURE__*/React.createElement(App, null));
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/main-menu/App.jsx", error: String((e && e.message) || e) }); }

// ui_kits/main-menu/MainMenu.jsx
try { (() => {
function MainMenu({
  onNav
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      width: 960,
      height: 540,
      overflow: "hidden",
      fontFamily: "var(--font-body)"
    }
  }, /*#__PURE__*/React.createElement("img", {
    src: "../../assets/backgrounds/menubackground.png",
    style: {
      position: "absolute",
      inset: 0,
      width: "100%",
      height: "100%",
      objectFit: "cover"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      background: "rgba(13,15,26,0.45)"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      zIndex: 1,
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      gap: 12,
      paddingTop: 24
    }
  }, /*#__PURE__*/React.createElement("img", {
    src: "../../assets/brand/logo.png",
    style: {
      height: 150,
      objectFit: "contain"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      color: "#BFD9FF",
      fontSize: 18,
      textShadow: "0 0 4px #000,0 0 4px #000"
    }
  }, "Best Score: 1240 \xA0\xB7\xA0 Best Time: 1:52"), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 8
    }
  }), /*#__PURE__*/React.createElement(MenuButton, {
    label: "Start Game",
    height: 48,
    onClick: () => onNav("result")
  }), /*#__PURE__*/React.createElement(MenuButton, {
    label: "Map",
    height: 40,
    onClick: () => onNav("map")
  }), /*#__PURE__*/React.createElement(MenuButton, {
    label: "Quests",
    height: 40
  }), /*#__PURE__*/React.createElement(MenuButton, {
    label: "Cases",
    height: 40
  }), /*#__PURE__*/React.createElement(MenuButton, {
    label: "Skins",
    height: 40,
    onClick: () => onNav("skins")
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      right: 16,
      bottom: 16
    }
  }, /*#__PURE__*/React.createElement(MenuButtonSmall, {
    label: "Quit Game"
  })));
}
function MenuButton({
  label,
  height,
  onClick
}) {
  const {
    GreenglenButton
  } = window.GoblinsOfGreenglenDesignSystem_aaca98;
  return /*#__PURE__*/React.createElement(GreenglenButton, {
    label: label,
    height: height,
    onClick: onClick
  });
}
function MenuButtonSmall({
  label
}) {
  const {
    GreenglenButton
  } = window.GoblinsOfGreenglenDesignSystem_aaca98;
  return /*#__PURE__*/React.createElement(GreenglenButton, {
    label: label,
    height: 40,
    style: {
      fontSize: 15
    }
  });
}
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/main-menu/MainMenu.jsx", error: String((e && e.message) || e) }); }

// ui_kits/main-menu/MapScreen.jsx
try { (() => {
const REGIONS = [{
  id: 1,
  name: "Region 1",
  status: "Available",
  desc: "6 levels · the classic Greenglen run"
}, {
  id: 2,
  name: "Region 2",
  status: "Locked",
  desc: "Complete all 6 main levels and a no-damage Level 6 finale to unlock"
}, {
  id: 3,
  name: "Region 3",
  status: "Coming Soon",
  desc: "Prerequisites met — content not yet released"
}];
function MapScreen({
  onBack
}) {
  const {
    SubmenuShell,
    GreenglenButton
  } = window.GoblinsOfGreenglenDesignSystem_aaca98;
  const [region, setRegion] = React.useState(1);
  const current = REGIONS.find(r => r.id === region);
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width: 960,
      height: 540
    }
  }, /*#__PURE__*/React.createElement(SubmenuShell, {
    title: "Campaign Map",
    background: "map"
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 12,
      justifyContent: "center"
    }
  }, REGIONS.map(r => /*#__PURE__*/React.createElement("button", {
    key: r.id,
    onClick: () => setRegion(r.id),
    style: {
      fontFamily: "var(--font-body)",
      fontSize: 15,
      padding: "6px 14px",
      background: r.id === region ? "rgba(232,179,61,0.25)" : "transparent",
      border: "1px solid var(--leaf-gold)",
      color: "var(--cream)",
      cursor: "pointer"
    }
  }, r.name))), /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: "center",
      color: current.status === "Available" ? "var(--forest-bright)" : current.status === "Locked" ? "#E88" : "var(--legendary)",
      fontSize: 18,
      fontFamily: "var(--font-display)"
    }
  }, current.status), /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: "center",
      color: "var(--cream)",
      fontSize: 15,
      maxWidth: 560,
      margin: "0 auto"
    }
  }, current.desc), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      justifyContent: "space-between"
    }
  }, /*#__PURE__*/React.createElement(GreenglenButton, {
    label: "Back",
    height: 40,
    onClick: onBack
  }), /*#__PURE__*/React.createElement(GreenglenButton, {
    label: "Play",
    height: 40,
    disabled: current.status !== "Available"
  }))));
}
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/main-menu/MapScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/main-menu/ResultScreen.jsx
try { (() => {
function ResultScreen({
  onMainMenu
}) {
  const {
    GreenglenHeading,
    StatValue,
    GreenglenButton
  } = window.GoblinsOfGreenglenDesignSystem_aaca98;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      width: 960,
      height: 540,
      background: "#1a2018",
      overflow: "hidden"
    }
  }, /*#__PURE__*/React.createElement("img", {
    src: "../../assets/backgrounds/level_bg.png",
    style: {
      position: "absolute",
      inset: 0,
      width: "100%",
      height: "100%",
      objectFit: "cover",
      opacity: 0.5
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      background: "rgba(6,9,10,0.68)"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      zIndex: 1,
      height: "100%",
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      justifyContent: "center",
      gap: 14
    }
  }, /*#__PURE__*/React.createElement(GreenglenHeading, {
    text: "Run Complete",
    size: 44,
    accent: "var(--legendary)"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 36
    }
  }, /*#__PURE__*/React.createElement(StatValue, {
    caption: "FINAL SCORE",
    value: 1240,
    color: "var(--cream)"
  }), /*#__PURE__*/React.createElement(StatValue, {
    caption: "RUN TIME",
    value: "2:14",
    color: "#B9D9F4"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      color: "#B8D6EA",
      fontSize: 16
    }
  }, "Best Score: 980 \xB7 Best Time: 2:31"), /*#__PURE__*/React.createElement("div", {
    style: {
      color: "var(--legendary)",
      fontFamily: "var(--font-display)",
      fontSize: 21
    }
  }, "New Highscore!", "\n", "New Best Time!"), /*#__PURE__*/React.createElement(GreenglenButton, {
    label: "Run Again",
    height: 46
  }), /*#__PURE__*/React.createElement(GreenglenButton, {
    label: "Main Menu",
    height: 46,
    onClick: onMainMenu
  })));
}
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/main-menu/ResultScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/main-menu/SkinsScreen.jsx
try { (() => {
const SKINS = [{
  id: "default",
  name: "Default Knight",
  tier: "default",
  texture: "../../assets/characters/skins/sprite_knight.png"
}, {
  id: "sapphire",
  name: "Sapphire Princess",
  tier: "starter",
  texture: "../../assets/characters/skins/sprite_princess_blue.png"
}, {
  id: "gold_knight",
  name: "Gold Knight",
  tier: "rare",
  texture: "../../assets/characters/skins/sprite_knight_gold.png"
}, {
  id: "emerald_knight",
  name: "Emerald Knight",
  tier: "rare",
  texture: "../../assets/characters/skins/sprite_knight_emerald.png"
}, {
  id: "pink_knight",
  name: "Pink Knight",
  tier: "epic",
  texture: "../../assets/characters/skins/sprite_knight_pink.png"
}, {
  id: "blood_knight",
  name: "Blood Knight",
  tier: "epic",
  texture: "../../assets/characters/skins/sprite_knight_blood.png"
}, {
  id: "black_knight",
  name: "Black Knight",
  tier: "epic",
  texture: "../../assets/characters/skins/sprite_knight_black.png"
}, {
  id: "gold_princess",
  name: "Golden Princess",
  tier: "legendary",
  texture: "../../assets/characters/skins/sprite_princess_gold.png"
}, {
  id: "green_princess",
  name: "Emerald Princess",
  tier: "legendary",
  texture: "../../assets/characters/skins/sprite_princess_green.png"
}, {
  id: "purple_princess",
  name: "Amethyst Princess",
  tier: "legendary",
  texture: "../../assets/characters/skins/sprite_princess_purple.png"
}, {
  id: "red_princess",
  name: "Ruby Princess",
  tier: "legendary",
  texture: "../../assets/characters/skins/sprite_princess_red.png"
}];
function SkinsScreen({
  onBack
}) {
  const {
    SubmenuShell,
    GreenglenButton,
    TierBadge
  } = window.GoblinsOfGreenglenDesignSystem_aaca98;
  const [selected, setSelected] = React.useState("gold_knight");
  const [equipped, setEquipped] = React.useState("default");
  const skin = SKINS.find(s => s.id === selected);
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width: 960,
      height: 540
    }
  }, /*#__PURE__*/React.createElement(SubmenuShell, {
    title: "Skins",
    background: "skins"
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 40,
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 340,
      height: 360,
      overflowY: "auto",
      display: "flex",
      flexDirection: "column",
      gap: 8
    }
  }, SKINS.map(s => /*#__PURE__*/React.createElement("button", {
    key: s.id,
    onClick: () => setSelected(s.id),
    style: {
      background: "none",
      border: "none",
      cursor: "pointer",
      textAlign: "left",
      padding: "6px 4px",
      fontFamily: "var(--font-body)",
      fontSize: 16,
      display: "flex",
      gap: 8,
      alignItems: "center"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--cream)",
      opacity: s.id === selected ? 1 : 0.5
    }
  }, s.id === selected ? "▶" : "　"), /*#__PURE__*/React.createElement(TierBadge, {
    tier: s.tier,
    label: s.name
  })))), /*#__PURE__*/React.createElement("div", {
    style: {
      width: 340,
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      gap: 10
    }
  }, /*#__PURE__*/React.createElement("img", {
    src: skin.texture,
    style: {
      width: 340,
      height: 230,
      objectFit: "contain"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      color: "#fff",
      fontSize: 24,
      fontFamily: "var(--font-display)"
    }
  }, skin.name), /*#__PURE__*/React.createElement(TierBadge, {
    tier: skin.tier
  }), skin.id === equipped && /*#__PURE__*/React.createElement("div", {
    style: {
      color: "#80FF99",
      fontSize: 16
    }
  }, "\u2713 Equipped"), /*#__PURE__*/React.createElement(GreenglenButton, {
    label: skin.id === equipped ? "Equipped" : "Equip",
    height: 40,
    disabled: skin.id === equipped,
    onClick: () => setEquipped(skin.id)
  }))), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement(GreenglenButton, {
    label: "Back",
    height: 40,
    onClick: onBack
  }))));
}
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/main-menu/SkinsScreen.jsx", error: String((e && e.message) || e) }); }

__ds_ns.TierBadge = __ds_scope.TierBadge;

__ds_ns.GreenglenButton = __ds_scope.GreenglenButton;

__ds_ns.GreenglenHeading = __ds_scope.GreenglenHeading;

__ds_ns.HeartsMeter = __ds_scope.HeartsMeter;

__ds_ns.StatValue = __ds_scope.StatValue;

__ds_ns.SubmenuShell = __ds_scope.SubmenuShell;

})();

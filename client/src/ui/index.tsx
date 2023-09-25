import { store } from "../store/store";
import { Wrapper } from "./wrapper";

import { MenuState } from "./components/navbar";
import React, { useState, useEffect } from "react";

import { menuEvents, tooltipEvent } from "../phaser/systems/eventSystems/eventEmitter";

import "../App.css";

import { MainMenuComponent } from "./components/mainMenuComponent";

export const UI = () => {
  const [opacity, setOpacity] = useState(1);
  const [menuState, setMenuState] = useState<MenuState>(MenuState.MAIN);

  const layers = store((state) => {
    return {
      networkLayer: state.networkLayer,
      phaserLayer: state.phaserLayer,
    };
  });

  const SetMenuState = (state: MenuState) => {
    console.log("called state change for menu", state);
    setMenuState(state);
  };

  //opacity control based on menu state
  useEffect(() => {
    if (menuState !== MenuState.MAP) {
      setOpacity(0.85);

      tooltipEvent.emit("closeTooltip", false);
    } else {
      setOpacity(0);
    }

    menuEvents.on("setMenuState", SetMenuState);

    return () => {
      menuEvents.off("setMenuState", SetMenuState);
    };
  }, [menuState]);

  if (!layers.networkLayer || !layers.phaserLayer) return <></>;

  return (
    <Wrapper>
      <div
        className="phaser-fadeout-background"
        style={{ opacity: opacity }}
      ></div>

      <MainMenuComponent layer={layers.phaserLayer} />
    </Wrapper>
  );
};

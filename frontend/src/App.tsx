import React from "react";
import { AuthBar } from "./components/AuthBar";
import { Articles } from "./pages/Articles";
import Login from "./pages/Login";
import { Detail } from "./pages/Detail";
import { BrowserRouter, Routes, Route, NavLink } from "react-router-dom";
import Clarify from "./pages/Clarify";
import ClarifyStreamDebug from "./pages/ClarifyStreamDebug";
import OpenAPI from "./pages/OpenAPI";
import ClarifyViewer from "./pages/ClarifyViewer";
import Style from "./pages/Style";
import { ToastContainer } from "./components/ToastContainer";
import { ReloginModal } from "./components/ReloginModal";
import { ThemeToggle } from "./components/ThemeToggle";
import { SchemeToggle } from "./components/SchemeToggle";

export default function App() {
  return (
    <BrowserRouter>
      <div className="ui-container">
        <h1 className="ui-title">Xingzuo Demo Frontend</h1>
        <AuthBar />
        <ToastContainer />
        <ReloginModal />
        <nav className="ui-row ui-row--gap-md ui-mt-md" aria-label="主导航">
          <NavLink to="/" end className="ui-btn ui-btn--ghost">Articles</NavLink>
          <NavLink to="/clarify" className="ui-btn ui-btn--ghost">Clarify</NavLink>
          <NavLink to="/clarify/viewer" className="ui-btn ui-btn--ghost">Clarify Viewer</NavLink>
          <NavLink to="/clarify/stream" className="ui-btn ui-btn--ghost">Clarify Stream</NavLink>
          <NavLink to="/openapi" className="ui-btn ui-btn--ghost">OpenAPI</NavLink>
          <NavLink to="/style" className="ui-btn ui-btn--ghost">Style</NavLink>
          <NavLink to="/login" className="ui-btn ui-btn--ghost">Login</NavLink>
          <SchemeToggle />
          <ThemeToggle />
        </nav>
        <div className="ui-mt-lg">
          <Routes>
            <Route path="/" element={<Articles />} />
            <Route path="/articles/:id" element={<Detail />} />
            <Route path="/clarify" element={<Clarify />} />
            <Route path="/clarify/viewer" element={<ClarifyViewer />} />
            <Route path="/clarify/stream" element={<ClarifyStreamDebug />} />
            <Route path="/openapi" element={<OpenAPI />} />
            <Route path="/style" element={<Style />} />
            <Route path="/login" element={<Login />} />
          </Routes>
        </div>
      </div>
    </BrowserRouter>
  );
}

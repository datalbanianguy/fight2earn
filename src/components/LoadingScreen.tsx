import React, { useEffect, useState } from 'react';
import '../App.css';

const LoadingScreen: React.FC = () => {
    const [progress, setProgress] = useState(0);

    useEffect(() => {
        const interval = setInterval(() => {
            setProgress((prev) => {
                if (prev >= 100) {
                    clearInterval(interval);
                    return 100;
                }
                return prev + 5;
            });
        }, 100);

        return () => clearInterval(interval);
    }, []);

    return (
        <div className="loading-screen">
            <div className="loading-content">
                <div className="loading-logo-container">
                    <img src="/fight-coin-logo.jpg" alt="FightCoin Arena" className="loading-logo" />
                </div>
                <h2 className="loading-text">Loading Arena...</h2>
                <div className="progress-bar-container">
                    <div className="progress-bar" style={{ width: `${progress}%` }}></div>
                </div>
            </div>
        </div>
    );
};

export default LoadingScreen;

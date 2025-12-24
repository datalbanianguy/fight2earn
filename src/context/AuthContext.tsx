import React, { createContext, useContext, useEffect, useState } from 'react';
import { supabase } from '../supabaseClient';
import WebApp from '@twa-dev/sdk';

interface User {
    telegram_id: number;
    username: string;
    balance_usdt: number;
    balance_fc: number;
    games_played: number;
    total_winnings?: number;
    last_faucet_claim: string | null;
}

interface AuthContextType {
    user: User | null;
    loading: boolean;
    refreshUser: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType>({ user: null, loading: true, refreshUser: async () => { } });

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
    const [user, setUser] = useState<User | null>(null);
    const [loading, setLoading] = useState(true);

    // Mock data for development outside Telegram
    const mockUser = {
        id: 123456789,
        username: 'mock_user',
        first_name: 'Mock',
        last_name: 'User',
    };

    useEffect(() => {
        const initAuth = async () => {
            let telegramUser;

            // Check if running in Telegram WebApp
            if (WebApp.initDataUnsafe && WebApp.initDataUnsafe.user) {
                telegramUser = WebApp.initDataUnsafe.user;
            } else {
                console.warn('Telegram WebApp not detected. Using Mock User.');
                telegramUser = mockUser;
            }

            if (telegramUser) {
                try {
                    // 1. Upsert User into Supabase
                    const { error: upsertError } = await supabase
                        .from('users')
                        .upsert({
                            telegram_id: telegramUser.id,
                            username: telegramUser.username || `user_${telegramUser.id}`,
                        }, { onConflict: 'telegram_id' });

                    if (upsertError) {
                        console.error('Error upserting user:', upsertError);
                        // Don't return here, might still be able to fetch if it exists
                    }

                    // 2. Fetch User Data
                    await fetchUser(telegramUser.id);

                } catch (error) {
                    console.error('Auth Init Error:', error);
                }
            }
            setLoading(false);
        };

        initAuth();
    }, []);

    const fetchUser = async (id: number) => {
        const { data, error } = await supabase
            .from('users')
            .select('*')
            .eq('telegram_id', id)
            .single();

        if (error) {
            console.error('Error fetching user:', error);
        } else {
            setUser(data);
        }
    };

    const refreshUser = async () => {
        if (user) {
            await fetchUser(user.telegram_id);
        }
    };

    return (
        <AuthContext.Provider value={{ user, loading, refreshUser }}>
            {children}
        </AuthContext.Provider>
    );
};

export const useAuth = () => useContext(AuthContext);

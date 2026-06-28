import { create } from 'zustand'

interface ChatState {
  messages: any[]
  addMessage: (msg: any) => void
}

export const useChatStore = create<ChatState>((set) => ({
  messages: [],
  addMessage: (msg) => set((state) => ({ messages: [...state.messages, msg] })),
}))

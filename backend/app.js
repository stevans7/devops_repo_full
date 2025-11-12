const express=require('express');const mongoose=require('mongoose');const cors=require('cors');
const app=express();app.use(cors());app.use(express.json());
const uri=process.env.MONGO_URI||'mongodb://localhost:27017/appointments';
mongoose.connect(uri).then(()=>console.log('Mongo OK')).catch(e=>console.error(e));
const Appointment=require('./models/appointments');
app.post('/api/appointments',async(req,res)=>{try{const a=await Appointment.create(req.body);res.status(201).json(a);}catch(e){res.status(400).json({error:e.message})}});
app.get('/healthz',(req,res)=>res.send('ok'));module.exports=app;
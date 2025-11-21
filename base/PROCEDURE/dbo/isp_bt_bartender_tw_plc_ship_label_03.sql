SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_BT_Bartender_TW_PLC_ship_Label_03                             */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2021-12-30 1.0  CSCHONG    Devops Scripts Combine (WMS-18640)              */ 
/* 2022-05-06 1.1  WLChooi    WMS-19591 - Add/modify columns (WL01)           */ 
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_BT_Bartender_TW_PLC_ship_Label_03]                      
(  @c_Sparm01            NVARCHAR(250),              
   @c_Sparm02            NVARCHAR(250),              
   @c_Sparm03            NVARCHAR(250),              
   @c_Sparm04            NVARCHAR(250),              
   @c_Sparm05            NVARCHAR(250),              
   @c_Sparm06            NVARCHAR(250),              
   @c_Sparm07            NVARCHAR(250),              
   @c_Sparm08            NVARCHAR(250),              
   @c_Sparm09            NVARCHAR(250),              
   @c_Sparm10            NVARCHAR(250),        
   @b_debug              INT = 0                         
)                      
AS                      
BEGIN                      
   SET NOCOUNT ON                 
   SET ANSI_NULLS OFF                
   SET QUOTED_IDENTIFIER OFF                 
   SET CONCAT_NULL_YIELDS_NULL OFF                                      
                              
   DECLARE                  
      @c_Uccno           NVARCHAR(20),                    
      @c_Sku             NVARCHAR(20),                         
      @n_intFlag         INT,     
      @n_CntRec          INT,    
      @c_SQL             NVARCHAR(4000),        
      @c_SQLSORT         NVARCHAR(4000),        
      @c_SQLJOIN         NVARCHAR(4000),
      @n_totalcase       INT,
      @n_sequence        INT,
      @c_skugroup        NVARCHAR(10),
      @n_CntSku          INT,
      @n_TTLQty          INT      
          
    
   DECLARE @d_Trace_StartTime  DATETIME,   
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),   
           @d_Trace_Step1      DATETIME,   
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20),
           @c_ExecStatements   NVARCHAR(4000),   
           @c_ExecArguments    NVARCHAR(4000)     
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
    -- SET RowNo = 0             
   SET @c_SQL = ''  
   SET @c_Sku = '' 
   SET @c_skugroup = ''    
   SET @n_totalcase = 0  
   SET @n_sequence  = 1 
   SET @n_CntSku = 1  
   SET @n_TTLQty = 0     
              
   CREATE TABLE [#Result] (             
      [ID]    [INT] IDENTITY(1,1) NOT NULL,                            
      [Col01] [NVARCHAR] (80) NULL,              
      [Col02] [NVARCHAR] (80) NULL,              
      [Col03] [NVARCHAR] (80) NULL,              
      [Col04] [NVARCHAR] (80) NULL,              
      [Col05] [NVARCHAR] (80) NULL,              
      [Col06] [NVARCHAR] (80) NULL,              
      [Col07] [NVARCHAR] (80) NULL,              
      [Col08] [NVARCHAR] (80) NULL,              
      [Col09] [NVARCHAR] (80) NULL,              
      [Col10] [NVARCHAR] (80) NULL,              
      [Col11] [NVARCHAR] (80) NULL,              
      [Col12] [NVARCHAR] (80) NULL,              
      [Col13] [NVARCHAR] (80) NULL,              
      [Col14] [NVARCHAR] (80) NULL,              
      [Col15] [NVARCHAR] (80) NULL,              
      [Col16] [NVARCHAR] (80) NULL,              
      [Col17] [NVARCHAR] (80) NULL,
      [Col18] [NVARCHAR] (80) NULL,
      [Col19] [NVARCHAR] (80) NULL,              
      [Col20] [NVARCHAR] (80) NULL,              
      [Col21] [NVARCHAR] (80) NULL,              
      [Col22] [NVARCHAR] (80) NULL,              
      [Col23] [NVARCHAR] (80) NULL,              
      [Col24] [NVARCHAR] (80) NULL,              
      [Col25] [NVARCHAR] (80) NULL,              
      [Col26] [NVARCHAR] (80) NULL,              
      [Col27] [NVARCHAR] (80) NULL,              
      [Col28] [NVARCHAR] (80) NULL,              
      [Col29] [NVARCHAR] (80) NULL,              
      [Col30] [NVARCHAR] (80) NULL,              
      [Col31] [NVARCHAR] (80) NULL,              
      [Col32] [NVARCHAR] (80) NULL,              
      [Col33] [NVARCHAR] (80) NULL,              
      [Col34] [NVARCHAR] (80) NULL,              
      [Col35] [NVARCHAR] (80) NULL,              
      [Col36] [NVARCHAR] (80) NULL,              
      [Col37] [NVARCHAR] (80) NULL,              
      [Col38] [NVARCHAR] (80) NULL,              
      [Col39] [NVARCHAR] (80) NULL,              
      [Col40] [NVARCHAR] (80) NULL,              
      [Col41] [NVARCHAR] (80) NULL,              
      [Col42] [NVARCHAR] (80) NULL,              
      [Col43] [NVARCHAR] (80) NULL,              
      [Col44] [NVARCHAR] (80) NULL,              
      [Col45] [NVARCHAR] (80) NULL,              
      [Col46] [NVARCHAR] (80) NULL,              
      [Col47] [NVARCHAR] (80) NULL,              
      [Col48] [NVARCHAR] (80) NULL,              
      [Col49] [NVARCHAR] (80) NULL,              
      [Col50] [NVARCHAR] (80) NULL,             
      [Col51] [NVARCHAR] (80) NULL,              
      [Col52] [NVARCHAR] (80) NULL,              
      [Col53] [NVARCHAR] (80) NULL,              
      [Col54] [NVARCHAR] (80) NULL,              
      [Col55] [NVARCHAR] (80) NULL,              
      [Col56] [NVARCHAR] (80) NULL,              
      [Col57] [NVARCHAR] (80) NULL,              
      [Col58] [NVARCHAR] (80) NULL,              
      [Col59] [NVARCHAR] (80) NULL,              
      [Col60] [NVARCHAR] (80) NULL             
     )            
              
            
   SET @c_SQLJOIN = +N' SELECT DISTINCT ISNULL(CT.TrackingNo,''''),pd.cartonno,CONVERT(NVARCHAR(10),o.editdate,111),ISNULL(C.long,''''),'       --4
                    + ' ISNULL(O.C_zip,''''),CASE WHEN ISNULL(oi.orderinfo03,'''')  IN (''Y'',''COD'') AND pd.cartonno = 1 THEN CAST(ISNULL(OI.PayableAmount,0) as nvarchar(10)) '
                    +N' WHEN ISNULL(oi.orderinfo03,'''') IN (''Y'',''COD'') AND pd.cartonno > 1 THEN N''請參閱主單'' ELSE N''無代收款'' END as Col06 ,'
                    + ' o.OrderKey,o.Route,ISNULL(o.C_Address1,''''),ISNULL(o.C_contact1,''''),' --10 
                    + ' ISNULL(o.notes,''''),ph.TTLCNTS,ISNULL(o.C_phone1,''''),ISNULL(CL.Long,''''),ISNULL(CL.UDF02,''''), ' --15    
                    + ' ISNULL(CL.Notes,''''),ISNULL(CL.UDF03,''''),ISNULL(CL1.UDF05,''''),ISNULL(oi.orderinfo03,''''), ISNULL(o.C_Address2,'''') ,'  --20   
                    --    + CHAR(13) +      
                    + ' ISNULL(o.C_Address3,''''),ISNULL(o.C_Address4,''''),ISNULL(o.C_Phone2,''''), ISNULL(o.BuyerPO,''''), ISNULL(OI.EcomOrderId,''''), '   --25   --WL01
                    + ' ISNULL(CL2.Description,''''), ISNULL(CL2.Notes,''''), ISNULL(CL2.Long,''''),'''','''','  --30  
                    + ' '''','''','''','''','''','''','''','''','''','''','   --40       
                    + ' '''','''','''','''','''','''','''','''','''','''', '  --50       
                    + ' '''','''','''','''','''','''','''','''','''','''' '   --60          
                    --  + CHAR(13) +            
                    + ' FROM PackHeader AS ph WITH (NOLOCK)'       
                    + ' JOIN PackDetail AS pd WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo'   
                    + ' JOIN ORDERS AS o WITH (NOLOCK) ON o.OrderKey = ph.OrderKey '    
                    + ' LEFT JOIN Storer ST WITH (NOLOCK) ON ST.storerkey=o.storerkey '              
                    + ' LEFT JOIN CARTONTRACK CT WITH (NOLOCK) ON CT.labelno=O.orderkey '
                    + ' LEFT JOIN CODELKUP C WITH (NOLOCK) ON listname = ''PLCshop'' and C.Code=O.facility and C.storerkey = O.storerkey'  
                    + ' LEFT JOIN ORDERINFO OI WITH (NOLOCK) ON OI.Orderkey = o.orderkey'   
                    + ' LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.Listname = ''COURIERADR'' AND CL.Code = o.Shipperkey AND CL.Storerkey = o.Storerkey AND CL.Code2 = '''' '       
                    + ' LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON CL1.Listname = ''Trackno'' AND CL1.Code = o.Shipperkey AND CL1.Storerkey = o.Storerkey AND CL1.Code2 = O.Ordergroup '    
                    + ' LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON CL2.Listname = ''WebsitInfo'' AND CL2.Code = OI.StoreName AND CL2.Storerkey = O.Storerkey '   --WL01  
                    + ' WHERE pd.pickslipno = @c_Sparm01 '   
                    + ' AND pd.labelno = @c_Sparm02 '    
                    + ' GROUP BY CT.TrackingNo,pd.cartonno,CONVERT(NVARCHAR(10),o.editdate,111),C.long,O.C_zip,o.OrderKey,o.Route, '       
                    + ' ISNULL(o.C_Address1,''''),ISNULL(o.C_contact1,''''),ISNULL(o.notes,''''),ph.TTLCNTS,ISNULL(o.C_phone1,''''),'   
                    + ' ISNULL(CL.Long,''''),ISNULL(CL.UDF02,''''),ISNULL(CL.Notes,''''),ISNULL(CL.UDF03,''''),ISNULL(CL1.UDF05,''''),'
                    + ' CAST(ISNULL(OI.PayableAmount,0) as NVARCHAR(10)), '         
                    + ' ISNULL(oi.orderinfo03,''''), ISNULL(o.C_Address2,'''') , ISNULL(o.C_Address3,'''') , ISNULL(o.C_Address4,''''), '        
                    + ' CAST(ISNULL(OI.PayableAmount,0) as nvarchar(10)), '
                    + ' CASE WHEN ISNULL(oi.orderinfo03,'''') IN (''Y'',''COD'') AND pd.cartonno = 1 THEN CAST(ISNULL(OI.PayableAmount,0) as nvarchar(10)) '
                    +N' WHEN ISNULL(oi.orderinfo03,'''') IN (''Y'',''COD'') AND pd.cartonno > 1 THEN N''請參閱主單'' ELSE N''無代收款'' END, ISNULL(o.C_Phone2,''''), '
                    + ' ISNULL(o.BuyerPO,''''), ISNULL(OI.EcomOrderId,''''), ISNULL(CL2.Description,''''), ISNULL(CL2.Notes,''''), ISNULL(CL2.Long,'''') '   --WL01

   IF @b_debug=1        
   BEGIN        
      SELECT @c_SQLJOIN          
   END                
              
   SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +           
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +           
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +           
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +           
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +           
             + ',Col55,Col56,Col57,Col58,Col59,Col60) '          
    
   SET @c_SQL = @c_SQL + @c_SQLJOIN        
        
   --EXEC sp_executesql @c_SQL          

   SET @c_ExecArguments = N'  @c_Sparm01      NVARCHAR(80)'    
                         + ', @c_Sparm02      NVARCHAR(80) '
                     
  
   EXEC sp_ExecuteSql  @c_SQL     
                     , @c_ExecArguments    
                     , @c_Sparm01    
                     , @c_Sparm02                           
        
   IF @b_debug=1        
   BEGIN          
      PRINT @c_SQL          
   END        

   IF @b_debug=1        
   BEGIN        
      SELECT @c_Sparm01 '@c_Sparm01',@c_Sparm02 '@c_Sparm01'
      SELECT * FROM #Result (nolock)        
   END  
               
EXIT_SP:    
  
   SET @d_Trace_EndTime = GETDATE()  
   SET @c_UserName = SUSER_SNAME()  
     
  -- EXEC isp_InsertTraceInfo   
      --@c_TraceCode = 'BARTENDER',  
      --@c_TraceName = 'isp_BT_Bartender_TW_PLC_ship_Label_03',  
      --@c_starttime = @d_Trace_StartTime,  
      --@c_endtime = @d_Trace_EndTime,  
      --@c_step1 = @c_UserName,  
      --@c_step2 = '',  
      --@c_step3 = '',  
      --@c_step4 = '',  
      --@c_step5 = '',  
      --@c_col1 = @c_Sparm01,   
      --@c_col2 = @c_Sparm02,  
      --@c_col3 = @c_Sparm03,  
      --@c_col4 = @c_Sparm04,  
      --@c_col5 = @c_Sparm05,  
      --@b_Success = 1,  
      --@n_Err = 0,  
      --@c_ErrMsg = ''              
   
   SELECT * FROM #Result (nolock) 
                                  
END -- procedure   



GO
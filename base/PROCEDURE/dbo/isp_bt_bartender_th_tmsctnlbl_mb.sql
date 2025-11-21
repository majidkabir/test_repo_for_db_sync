SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/                   
/* Copyright: IDS                                                             */                   
/* Purpose: isp_BT_Bartender_TH_TMSCTNLBL_MB                                  */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */                   
/* 2018-04-18 1.0  CSCHONG    Created (WMS-4428)                              */               
/******************************************************************************/                  
        
CREATE PROC [dbo].[isp_BT_Bartender_TH_TMSCTNLBL_MB]                        
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
 --SET ANSI_WARNINGS OFF                        
            
 DECLARE                    
  @c_OrderKey        NVARCHAR(10),  
  @c_pickslipno      NVARCHAR(20),                      
  @c_sku             NVARCHAR(10),    
  @c_skudescr        NVARCHAR(80),                             
  @n_intFlag         INT,       
  @n_Cntsku          INT,      
  @n_ttlctn          INT,  
  @n_pqty            INT,  
  @n_scube           FLOAT,  
  @n_sWgt            FLOAT,    
  @n_cartonno        INT,  
  @c_cube            NVARCHAR(10),  
  @c_wgt             NVARCHAR(10),      
  @c_SQL             NVARCHAR(4000),          
  @c_SQLSORT         NVARCHAR(4000),          
  @c_SQLJOIN         NVARCHAR(4000),       
  @c_storerkey       NVARCHAR(20),         
  @c_ExecStatements  NVARCHAR(4000),        
  @c_ExecArguments   NVARCHAR(4000)          
    
  DECLARE   @d_Trace_StartTime  DATETIME,     
            @d_Trace_EndTime    DATETIME,    
            @c_Trace_ModuleName NVARCHAR(20),     
            @d_Trace_Step1      DATETIME,     
            @c_Trace_Step1      NVARCHAR(20),    
            @c_UserName         NVARCHAR(20)       
    
 SET @d_Trace_StartTime = GETDATE()    
 SET @c_Trace_ModuleName = ''    
      
  -- SET RowNo = 0               
  SET @c_SQL = ''                  
        
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
        
      
SET @c_SQLJOIN = +' SELECT DISTINCT CASE WHEN ISNULL(@c_Sparm08,'''') = ''Y'' '  
     + '  THEN @c_Sparm10 ELSE CASE WHEN @c_Sparm06 = ''Y'' AND @c_Sparm08 = ''Y'' THEN @c_Sparm10 ELSE OH.OrderKey  END END,'  
     + ' RM.TruckType,OH.StorerKey,f.UserDefine08,oh.[route],'      
     + CHAR(13) +     
     +' OH.ExternOrderKey,OH.C_Company,CONVERT(NVARCHAR(10),MB.DepartureDate,103),'  
     +' CONVERT(NVARCHAR(10),OH.DeliveryDate,103),'  
     +' CASE WHEN  @c_Sparm06 = ''Y'' THEN '  
     + ' CAST(CAST(p.casecnt*s.STDcube as decimal(10,6))as NVARCHAR(80)) '  
     + ' ELSE CAST(CAST((sum(PID.qty/p.CaseCnt)*s.STDcube) as decimal(10,6)) AS NVARCHAR(80)) END,'    
     + CHAR(13) +   
     +' CASE WHEN  @c_Sparm06 = ''Y'' THEN '   
     +' CAST( CAST(p.casecnt*s.STDGROSSWGT as decimal(10,6)) as NVARCHAR(80)) ELSE '  
     + ' CAST(CAST((sum(PID.qty/p.CaseCnt)*s.STDGROSSWGT) as decimal(10,6))AS NVARCHAR(80)) END,'  
     + ' SUBSTRING(ISNULL(oh.Notes,'''') + ISNULL(oh.Notes2,''''),1,80),'   
     + ' CASE WHEN  ISNULL(@c_Sparm08,'''') =''Y'' and @c_Sparm06 = ''Y'' THEN PID.SKU ELSE ''-'' END,'  
     +' CASE WHEN  ISNULL(@c_Sparm08,'''') =''Y'' and @c_Sparm06 = ''Y'' THEN @c_Sparm09 ELSE ''-'' END,'  
     +' CASE WHEN  ISNULL(@c_Sparm08,'''') =''Y'' and @c_Sparm06 = ''Y'' THEN S.DESCR ELSE ''-'' END,'   
     + ' @c_Sparm04,@c_Sparm05,SUBSTRING(ISNULL(oh.c_address1,'''') + ISNULL(oh.c_address2,''''),1,80),'  
     + ' SUBSTRING(ISNULL(oh.c_address3,'''') + ISNULL(oh.c_address3,''''),1,80),'  
     + ' SUBSTRING(ISNULL(oh.c_city,'''') + ISNULL(oh.c_state,'''')+ ISNULL(oh.c_zip,''''),1,80), '     
     + CHAR(13) +    
     +' @c_Sparm03,@c_Sparm07,'''','''','''','''','''','''','''','''', '     
     + CHAR(13) +    
     +' '''','''','''','''','''','''','''','''','''','''','     
     + CHAR(13) +    
     +' '''','''','''','''','''','''','''','''','''','''', '     
     + CHAR(13) +     
     +' '''','''','''','''','''','''','''','''','''','''' '     
     + CHAR(13) +              
     + ' FROM MBOL MB WITH (NOLOCK)'         
     + ' JOIN ORDERS     OH WITH (NOLOCK) ON MB.MbolKey=OH.MBOLKey '  
     + ' JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey=OH.OrderKey '   
     + ' LEFT JOIN RouteMaster AS RM (NOLOCK) ON RM.[Route]=OH.[Route] '  
     + ' JOIN FACILITY AS f WITH (NOLOCK) ON f.Facility=oh.Facility ' + CHAR(13) +   
     + ' JOIN PICKDETAIL PID WITH (NOLOCK) ON PID.OrderKey= OD.OrderKey '   
     + '        AND PID.OrderLineNumber=OD.OrderLineNumber '  
     + '         AND PID.Sku=OD.Sku ' + CHAR(13) +   
     + ' JOIN SKU S WITH (NOLOCK) ON S.StorerKey=PID.StorerKey AND S.Sku=PID.SKU'  
     + ' JOIN PACK P WITH (NOLOCK) ON P.PackKey=S.PACKKey  '  
     + ' WHERE MB.MbolKey= @c_Sparm01 '     
     + ' AND PID.sku = @c_Sparm02 '    
     + ' AND pid.OrderKey = @c_Sparm03'  
     + ' GROUP BY CASE WHEN ISNULL(@c_Sparm08,'''') = ''Y'' '  
     + '  THEN @c_Sparm10 ELSE CASE WHEN @c_Sparm06 = ''Y'' AND @c_Sparm08 = ''Y'' THEN @c_Sparm10 ELSE OH.OrderKey END END,'  
     + ' RM.TruckType,OH.StorerKey,f.UserDefine08,oh.[route], '  
     + ' OH.ExternOrderKey,OH.C_Company,CONVERT(NVARCHAR(10),MB.DepartureDate,103),'  
     + ' CONVERT(NVARCHAR(10),OH.DeliveryDate,103),SUBSTRING(ISNULL(oh.Notes,'''') + ISNULL(oh.Notes2,''''),1,80), '  
     + ' PID.SKU,p.CaseCnt,S.DESCR,SUBSTRING(ISNULL(oh.c_address1,'''') + ISNULL(oh.c_address2,''''),1,80), '  
     + ' SUBSTRING(ISNULL(oh.c_address3,'''') + ISNULL(oh.c_address3,''''),1,80), '  
     + ' SUBSTRING(ISNULL(oh.c_city,'''') + ISNULL(oh.c_state,'''')+ ISNULL(oh.c_zip,''''),1,80),s.STDGROSSWGT,s.STDcube '     
       
           
  IF @b_debug=1          
  BEGIN          
   PRINT @c_SQLJOIN            
  END                  
        
  SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +             
     +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +             
     +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +             
     +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +             
     +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +             
     + ',Col55,Col56,Col57,Col58,Col59,Col60) '            
    
 SET @c_SQL = @c_SQL + @c_SQLJOIN          
       
 --EXEC sp_executesql @c_SQL    
   
  SET @c_ExecArguments = N'  @c_Sparm01         NVARCHAR(80)'    
                        + ' ,@c_Sparm02         NVARCHAR(80)'    
                        + ' ,@c_Sparm03         NVARCHAR(80)'    
                        + ' ,@c_Sparm04         NVARCHAR(80)'    
                        + ' ,@c_Sparm05         NVARCHAR(80)'    
                        + ' ,@c_Sparm06         NVARCHAR(80)'    
                        + ' ,@c_Sparm07         NVARCHAR(80)'    
                        + ' ,@c_Sparm08         NVARCHAR(80)'   
                        + ' ,@c_Sparm09         NVARCHAR(80)'   
                        + ' ,@c_Sparm10         NVARCHAR(80)'   
           
               
 EXEC sp_ExecuteSql     @c_SQL       
                      , @c_ExecArguments      
                      , @c_Sparm01   
                      , @c_Sparm02       
                      , @c_Sparm03      
                      , @c_Sparm04      
                      , @c_Sparm05      
                      , @c_Sparm06   
                      , @c_Sparm07  
                      , @c_Sparm08  
                      , @c_Sparm09  
                      , @c_Sparm10  
  
       
 IF @b_debug=1          
 BEGIN            
  PRINT @c_SQL            
 END    
     
 IF @b_debug=1          
 BEGIN          
   SELECT * FROM #Result (nolock)          
 END         
      
 SELECT * FROM #Result (nolock)          
       
 EXIT_SP:      
     
  SET @d_Trace_EndTime = GETDATE()    
  SET @c_UserName = SUSER_SNAME()    
      
  EXEC isp_InsertTraceInfo     
   @c_TraceCode = 'BARTENDER',    
   @c_TraceName = 'isp_BT_Bartender_TH_TMSCTNLBL_MB',    
   @c_starttime = @d_Trace_StartTime,    
   @c_endtime = @d_Trace_EndTime,    
   @c_step1 = @c_UserName,    
   @c_step2 = '',    
   @c_step3 = '',    
   @c_step4 = '',    
   @c_step5 = '',    
   @c_col1 = @c_Sparm01,     
   @c_col2 = @c_Sparm02,    
   @c_col3 = @c_Sparm03,    
   @c_col4 = @c_Sparm04,    
   @c_col5 = @c_Sparm05,    
   @b_Success = 1,    
   @n_Err = 0,    
   @c_ErrMsg = ''                
    
     
               
 END -- procedure     
  

GO
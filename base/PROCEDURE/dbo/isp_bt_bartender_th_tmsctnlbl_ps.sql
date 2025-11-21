SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/                   
/* Copyright: IDS                                                             */                   
/* Purpose: isp_BT_Bartender_TH_TMSCTNLBL_PS                                  */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */                   
/* 2018-04-18 1.0  CSCHONG    Created (WMS-4428)                              */               
/******************************************************************************/                  
        
CREATE PROC [dbo].[isp_BT_Bartender_TH_TMSCTNLBL_PS]                        
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
  @c_sku             NVARCHAR(20),    
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
    
  DECLARE @d_Trace_StartTime   DATETIME,     
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
        
    IF NOT EXISTS (SELECT 1 FROM PACKHEADER PH WITH (NOLOCK)  
            WHERE Pickslipno = @c_Sparm01)  
   BEGIN  
      SELECT @c_Sparm01 = PH.Pickslipno  
   FROM PACKHEADER PH WITH (NOLOCK)  
   WHERE orderkey = @c_Sparm03  
  
   SELECT @c_Sparm08 = MAX(OD.uom)  
   FROM PICKDETAIL OD WITH (NOLOCK)  
   WHERE Orderkey = @c_Sparm03  
  
   SET @c_Sparm02 = @c_Sparm07  
   SET @c_Sparm07 = @c_Sparm07  
  
   END  
      
SET @c_SQLJOIN = +' SELECT DISTINCT CASE WHEN @c_Sparm08 = ''6'' AND @c_Sparm10 = '''' THEN OH.OrderKey ELSE @c_Sparm10 END , '  
     + ' RM.TruckType,OH.StorerKey,f.UserDefine08,oh.[route],'      
     + CHAR(13) +     
     +' OH.ExternOrderKey,OH.C_Company,ISNULL(CONVERT(NVARCHAR(10),MB.DepartureDate,103),''''),'  
     +' CONVERT(NVARCHAR(10),OH.DeliveryDate,103),CAST(PI.[Cube] AS NVARCHAR(80)),'    
     + CHAR(13) +    
     +' CAST(PI.[weight] AS NVARCHAR(80)),SUBSTRING(ISNULL(oh.Notes,'''') + ISNULL(oh.Notes2,''''),1,80),'''','''','''','   
     + ' CAST(PD.cartonno as NVARCHAR(5)),'''',SUBSTRING(ISNULL(oh.c_address1,'''') + ISNULL(oh.c_address2,''''),1,80),'  
     + ' SUBSTRING(ISNULL(oh.c_address3,'''') + ISNULL(oh.c_address3,''''),1,80),'  
     + ' SUBSTRING(ISNULL(oh.c_city,'''') + ISNULL(oh.c_state,'''')+ ISNULL(oh.c_zip,''''),1,80), '     
     + CHAR(13) +    
     +' @c_Sparm03,@c_Sparm07,'''','''','''','''','''','''','''','''', '     
     + CHAR(13) +    
     +' '''','''','''','''','''','''','''','''','''','''','     
     + CHAR(13) +    
     +' '''','''','''','''','''','''','''','''','''','''', '     
     + CHAR(13) +     
     +' '''','''','''','''','''','''','''','''','''',PH.pickslipno '     
     + CHAR(13) +              
     + ' FROM PACKHEADER PH WITH (NOLOCK)'         
     + ' JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickslipNo) '  
     + ' JOIN ORDERS     OH WITH (NOLOCK) ON (PH.Orderkey = OH.Orderkey) '  
     + ' JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey=OH.OrderKey '   
     + ' LEFT JOIN MBOL MB WITH (NOLOCK) ON MB.MbolKey=OH.MBOLKey ' + CHAR(13) +   
     + ' LEFT JOIN RouteMaster AS RM (NOLOCK) ON RM.[Route]=OH.[Route] '  
     + ' JOIN FACILITY AS f WITH (NOLOCK) ON f.Facility=oh.Facility ' + CHAR(13) +   
     + ' JOIN PICKDETAIL PID WITH (NOLOCK) ON PID.OrderKey= OD.OrderKey '   
     + '        AND PID.OrderLineNumber=OD.OrderLineNumber '  
     + '         AND PID.Sku=OD.Sku ' + CHAR(13) +   
     + ' LEFT JOIN PACKINFO PI (NOLOCK) ON PI.PickSlipNo = PD.PickSlipNo AND PI.CartonNo=PD.CartonNo   '  
     + ' WHERE PH.PickSlipNo=@c_Sparm01 '     
     + ' AND PD.CartonNo = CAST(@c_Sparm02 AS INT) '    
     + ' AND ph.OrderKey = @c_Sparm03'  
       
           
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
                        + ' ,@c_Sparm07         NVARCHAR(80)'    
                        + ' ,@c_Sparm08         NVARCHAR(80)'  
                        + ' ,@c_Sparm10         NVARCHAR(80)'      
           
               
 EXEC sp_ExecuteSql     @c_SQL       
                      , @c_ExecArguments      
                      , @c_Sparm01   
                      , @c_Sparm02       
                      , @c_Sparm03      
                      , @c_Sparm04    
                      , @c_Sparm07    
                      , @c_Sparm08    
                      , @c_Sparm10      
  
       
 IF @b_debug=1          
 BEGIN            
  PRINT @c_SQL            
 END    
     
 IF @b_debug=1          
 BEGIN          
   SELECT * FROM #Result (nolock)          
 END          
   
 DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
 SELECT DISTINCT col21,CAST(col16 AS INT),col03,col09,col10,col60     
 FROM   #Result     
 WHERE col60 = @c_Sparm01   
 AND col16 = @c_Sparm02   
 --AND col01 = @c_Sparm03  
    
 OPEN CUR_RESULT     
     
 FETCH NEXT FROM CUR_RESULT INTO @c_orderkey,@n_cartonno,@c_storerkey,@c_cube,@c_wgt,@c_pickslipno    
     
 WHILE @@FETCH_STATUS <> -1    
 BEGIN     
   
   
 SET @n_ttlctn = 1  
 SET @n_pqty = 0  
 SET @n_Cntsku = 1  
 SET @c_skudescr = ''  
 SET @c_sku = ''  
 SET @n_scube = 0.00  
 SET @n_sWgt = 0.00  
   
 SELECT @n_ttlctn = COUNT(DISTINCT PD.CartonNo)  
 FROM PACKDetail PD WITH (NOLOCK)  
 WHERE PD.PickSlipNo = @c_pickslipno  
 --AND PD.CartonNo=@n_cartonno  
   
 SELECT @n_Cntsku = COUNT(DISTINCT PD.sku)   
 FROM PACKDetail PD WITH (NOLOCK)  
 WHERE PD.PickSlipNo = @c_pickslipno  
 AND PD.CartonNo=@n_cartonno  
   
 SELECT @n_pqty = SUM(PD.qty)  
 FROM PACKDetail PD WITH (NOLOCK)  
 WHERE PD.PickSlipNo = @c_pickslipno  
 AND PD.CartonNo = @n_cartonno  
   
 IF @n_Cntsku > 1  
 BEGIN  
  SET @c_sku = 'MIX'  
  SET @c_skudescr = 'MIX'  
 END  
 ELSE  
 BEGIN  
   SELECT DISTINCT @c_sku = PD.sku  
   FROM PACKDetail PD WITH (NOLOCK)  
   WHERE PD.PickSlipNo = @c_pickslipno  
   AND PD.CartonNo = @n_cartonno   
     
   SELECT @c_skudescr = S.DESCR  
   FROM Sku S WITH (NOLOCK)  
   WHERE S.StorerKey=@c_storerkey  
   AND S.sku = @c_sku   
     
 END  
   
 IF @c_cube = '' AND @c_wgt = ''  
 BEGIN  
  SELECT @n_scube = SUM(pd.qty*s.STDCUBE)  
        ,@n_sWgt = SUM(pd.qty * s.STDGROSSWGT)  
   FROM PACKDetail PD WITH (NOLOCK)  
   JOIN SKU S WITH (NOLOCK) ON S.StorerKey=PD.StorerKey AND S.Sku=PD.SKU  
   WHERE PD.PickSlipNo = @c_pickslipno  
   AND PD.CartonNo = @n_cartonno   
 END  
  
 if @b_debug='3'  
 BEGIN  
 SELECT @c_sku '@c_sku',@c_OrderKey '@c_OrderKey',@c_pickslipno '@c_pickslipno'  
  
 END  
   
   
 UPDATE #Result  
 SET col10 = CASE WHEN @n_scube <> 0.00 THEN CAST(@n_scube AS NVARCHAR(10)) ELSE col10 END  
    ,col11 = CASE WHEN @n_sWgt <> 0.00 THEN CAST(@n_sWgt AS NVARCHAR(10)) ELSE col11 END   
    ,col13 = @c_sku  
    ,col14 = CAST(@n_pqty AS NVARCHAR(10))  
    ,col15 = @c_skudescr  
    ,col17 = CAST(@n_ttlctn AS NVARCHAR(10))  
 WHERE Col21 = @c_OrderKey  
 --AND col16=CAST(@n_cartonno AS NVARCHAR(5))  
 AND Col60 = @c_pickslipno  
   
  FETCH NEXT FROM CUR_RESULT INTO @c_orderkey,@n_cartonno,@c_storerkey,@c_cube,@c_wgt,@c_pickslipno    
 END     
      
 SELECT * FROM #Result (nolock)          
       
 EXIT_SP:      
     
  SET @d_Trace_EndTime = GETDATE()    
  SET @c_UserName = SUSER_SNAME()    
      
  EXEC isp_InsertTraceInfo     
   @c_TraceCode = 'BARTENDER',    
   @c_TraceName = 'isp_BT_Bartender_TH_TMSCTNLBL_PS',    
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
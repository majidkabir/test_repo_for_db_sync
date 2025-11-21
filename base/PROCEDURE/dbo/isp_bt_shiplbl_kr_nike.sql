SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                     
/* Copyright: IDS                                                             */                     
/* Purpose: isp_BT_SHIPLBL_KR_NIKE                                            */                     
/*                                                                            */                     
/* Modifications log:                                                         */                     
/*                                                                            */                     
/* Date        Rev  Author     Purposes                                       */                     
/* 02-FEB-2023 1.0  MINGLE     Devops Scripts combine(WMS-21684 Created)      */       
/******************************************************************************/                    
       
CREATE   PROC [dbo].[isp_BT_SHIPLBL_KR_NIKE]                          
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
   @b_debug             INT = 0                            
)                          
AS                          
BEGIN                          
   SET NOCOUNT ON                     
   SET ANSI_NULLS OFF                    
   SET QUOTED_IDENTIFIER OFF                     
   SET CONCAT_NULL_YIELDS_NULL OFF                    
 --  SET ANSI_WARNINGS OFF                          
     
          
        
  DECLARE @d_Trace_StartTime   DATETIME,       
           @d_Trace_EndTime    DATETIME,      
           @c_Trace_ModuleName NVARCHAR(20),       
           @d_Trace_Step1      DATETIME,       
           @c_Trace_Step1      NVARCHAR(20),      
           @c_UserName         NVARCHAR(20),    
           @c_SQL             NVARCHAR(4000),          
           @c_SQLJOIN         NVARCHAR(4000)             
               
 DECLARE @c_ExecStatements         NVARCHAR(MAX)      
         , @c_ExecArguments        NVARCHAR(MAX)      
         , @c_ExecStatements2      NVARCHAR(MAX)      
         , @c_ExecStatementsAll    NVARCHAR(MAX)        
         , @n_continue             INT   
         
         ,@c_Col31            NVARCHAR(80)  
         ,@c_Col32            NVARCHAR(80)
         ,@c_Col33            NVARCHAR(80)
         ,@c_Col34            NVARCHAR(80)
         ,@c_Col35            NVARCHAR(80)
         ,@c_Col36            NVARCHAR(80)
         ,@c_Col37            NVARCHAR(80)
         ,@c_Col38            NVARCHAR(80)
         ,@c_Col39            NVARCHAR(80)
         ,@n_ID               INT
         ,@c_Pickslipno       NVARCHAR(80)
         ,@c_Labelno          NVARCHAR(80)
         ,@c_LabelLine        NVARCHAR(80)
         ,@c_Sku              NVARCHAR(80)
         ,@c_descr            NVARCHAR(80)
         ,@c_qty              NVARCHAR(80)
         ,@c_Col47            NVARCHAR(80)  
         ,@c_Col48            NVARCHAR(80)
         ,@c_Col49            NVARCHAR(80)
         ,@c_Col50            NVARCHAR(80)
         ,@c_Col51            NVARCHAR(80)
         ,@c_Col52            NVARCHAR(80)
         ,@c_Col53            NVARCHAR(80)
         ,@c_Col54            NVARCHAR(80)
         ,@c_Col55            NVARCHAR(80)
                    
      
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
     
     CREATE TABLE [#PADItem] (               
      [ID]           [INT] IDENTITY(1,1) NOT NULL,  
      [Pickslipno]   NVARCHAR(20) NULL, 
      [Labelno]      NVARCHAR(50) NULL,   
      [LabelLine]    NVARCHAR(50) NULL, 
      [SKU]          NVARCHAR(30) NULL,    
      [ItemDescr]    NVARCHAR(80) NULL,
      [QTY]          NVARCHAR(20) NULL)  
                
        IF @b_debug=1            
         BEGIN            
            PRINT 'start'              
         END            
SET @c_SQLJOIN = +' SELECT DISTINCT OH.ORDERKEY,OH.EXTERNORDERKEY,OH.BUYERPO,OH.C_CONTACT1,OH.C_CONTACT2,OH.C_COMPANY,OH.C_PHONE1 ' + CHAR(13) --7  
     +' ,OH.C_PHONE2,OH.C_STATE,OH.C_CITY '+ CHAR(13) --10  
     +' ,SUBSTRING((OH.C_Address1 + '' '' + OH.C_Address2 + '' '' + OH.C_Address3 + '' '' + OH.C_Address4), 1, 80) AS C_ADDRESS ' + CHAR(13) --11  
     +' ,OH.C_Address1, OH.C_Address2, OH.C_Address3, OH.C_Address4 ' + CHAR(13) --15  
     +' ,OH.C_ZIP,SUBSTRING(OH.C_Contact1,1,LEN(OH.C_Contact1) - LEN(RIGHT(OH.C_Contact1, 1))) + ''*'' ' + CHAR(13) --17  
     + ',SUBSTRING(OH.C_Contact2,1,LEN(OH.C_Contact2) - LEN(RIGHT(OH.C_Contact2, 1))) + ''*'' ' + CHAR(13) --18  
     +' ,SUBSTRING(OH.C_Phone1,1,LEN(OH.C_Phone1) - LEN(RIGHT(OH.C_Phone1, 4))) + ''****'' ' + CHAR(13) --19  
     +' ,SUBSTRING(OH.C_Phone2,1,LEN(OH.C_Phone2) - LEN(RIGHT(OH.C_Phone2, 4))) + ''****'',OH.DISCHARGEPLACE ' + CHAR(13) --21  
     +' ,OH.M_ADDRESS1,OH.M_ADDRESS2,OH.M_ZIP,OH.M_PHONE1,OH.M_PHONE2,OH.M_COUNTRY,OH.M_ADDRESS3,OH.M_STATE,OH.M_ADDRESS4 ' + CHAR(13) --30  
     +' ,'''','''','''','''','''','''','''','''','''',PAD.CARTONNO ' + CHAR(13) --40      
     --+' ,CASE WHEN PAD.LABELLINE = ''00001'' THEN SKU.DESCR ELSE '''' END AS DESCR1 ' --32  
     --+' ,CASE WHEN PAD.LABELLINE = ''00001'' THEN CAST(PAD.QTY AS NVARCHAR) ELSE '''' END AS QTY1 ' --33             
     --+' ,CASE WHEN PAD.LABELLINE = ''00002'' THEN PAD.SKU ELSE '''' END AS SKU2 ' --34  
     --+' ,CASE WHEN PAD.LABELLINE = ''00002'' THEN SKU.DESCR ELSE '''' END AS DESCR2 ' --35  
     --+' ,CASE WHEN PAD.LABELLINE = ''00002'' THEN CAST(PAD.QTY AS NVARCHAR) ELSE '''' END AS QTY2 ' --36  
     --+' ,CASE WHEN PAD.LABELLINE = ''00003'' THEN PAD.SKU ELSE '''' END AS SKU3 ' --37  
     --+' ,CASE WHEN PAD.LABELLINE = ''00003'' THEN SKU.DESCR ELSE '''' END AS DESCR3 ' --38  
     --+' ,CASE WHEN PAD.LABELLINE = ''00003'' THEN CAST(PAD.QTY AS NVARCHAR) ELSE '''' END AS QTY3 ' --39  
     --+' ,PAD.CARTONNO ' --40  
     +' ,Substring(PAD.labelno,1,4) + ''-'' + Substring(PAD.labelno,5,4)  +''-'' +  Substring(PAD.labelno,9,4)  ' + CHAR(13) --41  
     +' ,PAD.LABELNO,'''',PAD.REFNO2,OH.NOTES,OH.NOTES2 ' + CHAR(13) --46  
     +' ,'''','''','''','''','''','''','''','''','''',ISNULL(OH.M_Contact1,''''),'''','''',PH.PICKSLIPNO,''KR'' ' + CHAR(13) --60   
     +' FROM PACKHEADER PH WITH (NOLOCK) '  + CHAR(13)
     +' JOIN PACKDETAIL PAD WITH (NOLOCK) ON (PAD.Pickslipno = PH.Pickslipno) '  + CHAR(13)
     +' JOIN ORDERS OH WITH (NOLOCK) ON (OH.OrderKey=PH.OrderKey)   '  + CHAR(13)
     +' JOIN SKU WITH (NOLOCK) ON (SKU.SKU = PAD.SKU AND SKU.STORERKEY = PAD.STORERKEY) '  + CHAR(13)
     +' WHERE PAD.PickSlipNo = @c_Sparm01 '       + CHAR(13)
  --   +' AND PAD.Cartonno = CASE WHEN ISNULL(RTRIM(@c_Sparm02),'''')<> '''' THEN @c_Sparm02 ELSE PAD.Cartonno END '  
     +' AND PAD.LABELNO = @c_Sparm02'+ CHAR(13)
     +' GROUP BY OH.ORDERKEY,OH.EXTERNORDERKEY,OH.BUYERPO,OH.C_CONTACT1,OH.C_CONTACT2,OH.C_COMPANY,OH.C_PHONE1,OH.C_PHONE2 '  + CHAR(13)
     +' ,OH.C_STATE,OH.C_CITY,OH.C_Address1,OH.C_Address2,OH.C_Address3,OH.C_Address4,OH.C_ZIP '  + CHAR(13)
     +' ,OH.DISCHARGEPLACE,OH.M_ADDRESS1,OH.M_ADDRESS2,OH.M_ZIP,OH.M_PHONE1,OH.M_PHONE2,OH.M_COUNTRY '  + CHAR(13)
     +' ,OH.M_ADDRESS3,OH.M_STATE,OH.M_ADDRESS4,PAD.LABELLINE '  + CHAR(13)
     +' ,PAD.SKU,SKU.DESCR,PAD.QTY,PAD.CARTONNO,PAD.LABELNO,PAD.REFNO2,OH.NOTES,OH.NOTES2,PH.PICKSLIPNO,ISNULL(OH.M_Contact1,'''') '  + CHAR(13)
  
                           
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
        
  --SET @c_SQL = @c_SQL + @c_SQLJOIN      
      
  --SET @c_SQL = @c_SQL + @c_SQLJOIN       
       SET @c_ExecStatements = @c_SQL + CHAR(13) + @c_SQLJOIN     
           
       IF @b_debug=1            
       BEGIN            
         SELECT @c_ExecStatements              
       END      
           
       SET @c_ExecArguments = N'@c_Sparm01    NVARCHAR(60)'      
                             +',@c_Sparm02    NVARCHAR(60)'      
                                         
      
        EXEC sp_ExecuteSql @c_ExecStatements       
                         , @c_ExecArguments      
                         , @c_Sparm01      
                         , @c_Sparm02      
      
     IF @@ERROR <> 0           
     BEGIN      
       SET @n_continue = 3      
       ROLLBACK TRAN      
       GOTO EXIT_SP      
     END           
    
        
            
   --EXEC sp_executesql @c_SQL              
            
   IF @b_debug=1            
   BEGIN              
       PRINT @c_SQL              
   END      
   
   INSERT INTO #PADItem (Pickslipno,Labelno,LabelLine,Sku,ItemDescr,QTY)   
   SELECT DISTINCT TOP 6 PAD.Pickslipno, PAD.Labelno, PAD.LabelLine, PAD.SKU, LTRIM(RTRIM(S.descr)), CAST(PAD.QTY AS NVARCHAR)   
   FROM PACKDETAIL PAD (NOLOCK)                
   JOIN SKU S WITH (NOLOCK) ON (S.SKU = PAD.SKU AND S.STORERKEY = PAD.STORERKEY)
   WHERE PAD.PICKSLIPNO = @c_sparm01 AND PAD.LABELNO = @c_sparm02
   ORDER BY PAD.Pickslipno, PAD.Labelno, PAD.LabelLine
   
   SET @c_Col31 = '' 
   SET @c_Col32 = '' 
   SET @c_Col33 = '' 
   SET @c_Col34 = '' 
   SET @c_Col35 = '' 
   SET @c_Col36 = '' 
   SET @c_Col37 = '' 
   SET @c_Col38 = '' 
   SET @c_Col39 = '' 

   SET @c_Col47 = '' 
   SET @c_Col48 = '' 
   SET @c_Col49 = '' 
   SET @c_Col50 = '' 
   SET @c_Col51 = '' 
   SET @c_Col52 = '' 
   SET @c_Col53 = '' 
   SET @c_Col54 = '' 
   SET @c_Col55 = '' 
   
   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
   SELECT DISTINCT ID, Pickslipno,Labelno,LabelLine,Sku,ItemDescr,QTY
   FROM #PADItem
   WHERE Pickslipno = @c_sparm01 AND Labelno = @c_sparm02
   ORDER BY ID
   
   OPEN CUR_RESULT
   
   FETCH NEXT FROM CUR_RESULT INTO @n_ID, @c_Pickslipno, @c_Labelno, @c_LabelLine, @c_Sku, @c_descr, @c_QTY
   
   WHILE @@FETCH_STATUS <>-1
   BEGIN
   IF @n_ID = 1 
   BEGIN
         SET @c_Col31 = @c_Sku
         SET @c_Col32 = @c_descr
         SET @c_Col33 = @c_QTY
   END
   ELSE IF @n_ID = 2 
   BEGIN
         SET @c_Col34 = @c_Sku
         SET @c_Col35 = @c_descr
         SET @c_Col36 = @c_QTY
   END
   ELSE IF @n_ID = 3 
   BEGIN
         SET @c_Col37 = @c_Sku
         SET @c_Col38 = @c_descr
         SET @c_Col39 = @c_QTY
   END
   ELSE IF @n_ID = 4
   BEGIN
         SET @c_Col47 = @c_Sku
         SET @c_Col48 = @c_descr
         SET @c_Col49 = @c_QTY
   END
   ELSE IF @n_ID = 5 
   BEGIN
         SET @c_Col50 = @c_Sku
         SET @c_Col51 = @c_descr
         SET @c_Col52 = @c_QTY
   END
   ELSE IF @n_ID = 6 
   BEGIN
         SET @c_Col53 = @c_Sku
         SET @c_Col54 = @c_descr
         SET @c_Col55 = @c_QTY
   END
   FETCH NEXT FROM CUR_RESULT INTO @n_ID, @c_Pickslipno, @c_Labelno, @c_LabelLine, @c_Sku, @c_descr, @c_QTY
   END
   
   CLOSE CUR_RESULT  
   DEALLOCATE CUR_RESULT  
   
   UPDATE #Result  
   SET Col31 = @c_Col31,  
       Col32 = @c_Col32,  
       Col33 = @c_Col33,  
       Col34 = @c_Col34,  
       Col35 = @c_Col35,
       Col36 = @c_Col36,
       Col37 = @c_Col37,
       Col38 = @c_Col38,
       Col39 = @c_Col39,
       Col47 = @c_Col47,
       Col48 = @c_Col48,
       Col49 = @c_Col49,
       Col50 = @c_Col50, 
       Col51 = @c_Col51,
       Col52 = @c_Col52,
       Col53 = @c_Col53,
       Col54 = @c_Col54,
       Col55 = @c_Col55    
   WHERE Col59 =@c_Sparm01  
   
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
         @c_TraceName = 'isp_BT_SHIPLBL_KR_NIKE',      
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
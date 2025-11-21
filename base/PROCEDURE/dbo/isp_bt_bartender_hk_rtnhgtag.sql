SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: BarTender sku return hang tag label                               */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2021-06-01 1.0  CSCHONG    Created(WMS-17136)                              */    
/* 2021-06-17 2.0  CSCHONG    WMS-17286 revised logic (CS01)                  */         
/* 2021-07-13 2.1  CSCHONG    WMS-17286 revised col02 and col04 (CS02)        */     
/* 2021-08-04 2.2  CSCHONG    WMS-17534 support duplicate sku (CS03)          */   
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_BT_Bartender_HK_RTNHGTAG]                      
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
                              
   DECLARE                  
      @n_copy            INT,                    
      @c_ExternOrderKey  NVARCHAR(10),              
      @c_Deliverydate    DATETIME,              
      @n_intFlag         INT,     
      @n_CntRec          INT,    
      @c_SQL             NVARCHAR(4000),        
      @c_SQLSORT         NVARCHAR(4000),        
      @c_SQLJOIN         NVARCHAR(4000)      
    
  DECLARE  @d_Trace_StartTime   DATETIME,   
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),   
           @d_Trace_Step1      DATETIME,   
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20),
           @c_ExecArguments    NVARCHAR(4000),
           @c_condition1       NVARCHAR(500),
           @c_orderby          NVARCHAR(500)     
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
    -- SET RowNo = 0             
    SET @c_SQL = ''       

       
    SET @n_copy = 0
    
    SET @n_copy = CAST (@c_Sparm03 AS INT)

    IF @n_copy > 2000
    BEGIN
     GOTO EXIT_SP

    END
             
              
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
              
  --CS01 START 

  SET @c_orderby = N' ORDER BY S.sku'

  IF ISNULL(@c_Sparm04,'') <> '' AND ISNULL(@c_Sparm05,'') = ''
  BEGIN
     SET @c_condition1 = N' AND S.sku = @c_Sparm02 OR s.sku = @c_Sparm04 '
  END
  ELSE IF ISNULL(@c_Sparm04,'') = '' AND ISNULL(@c_Sparm05,'') <> ''
  BEGIN
     SET @c_condition1 = N' AND S.sku = @c_Sparm02 OR s.sku = @c_Sparm05 '
  END
  ELSE IF ISNULL(@c_Sparm04,'') <> '' AND ISNULL(@c_Sparm05,'') <> ''
  BEGIN
     SET @c_condition1 = N' AND S.sku = @c_Sparm02 OR s.sku = @c_Sparm04 OR s.sku = @c_Sparm05 '
  END
  ELSE IF ISNULL(@c_Sparm04,'') = '' AND ISNULL(@c_Sparm05,'') = ''
  BEGIN
     SET @c_condition1 = N' AND S.sku = @c_Sparm02  '
  END
 

 IF @n_copy = 1
 BEGIN    
  --CS02 START  
  --SET @c_SQLJOIN = +' SELECT s.style,SUBSTRING(s.DESCR, CHARINDEX(''-'',s.DESCR)+1, '
  --           + ' CHARINDEX(''-'',s.DESCR,CHARINDEX(''-'',s.DESCR)+1)-CHARINDEX(''-'',s.DESCR)-1),s.color,'
  --           --+ ' SUBSTRING(s.DESCR, CHARINDEX(''-'', S.DESCR, CHARINDEX(''-'',S.DESCR)+1)+1, CHARINDEX(''-'',S.DESCR, '
  --           --+ ' CHARINDEX(''-'', S.DESCR, CHARINDEX(''-'',S.DESCR)+1)+1)-CHARINDEX(''-'', S.DESCR, CHARINDEX(''-'',S.DESCR)+1)-1),' --4   
  --           + ' CASE WHEN CHARINDEX(''-'',S.DESCR,CHARINDEX(''-'', S.DESCR, CHARINDEX(''-'',S.DESCR)+1)+1) <> 0 '
  --           + ' THEN SUBSTRING(S.DESCR, CHARINDEX(''-'', S.DESCR, CHARINDEX(''-'',S.DESCR)+1)+1, '
  --           + ' CHARINDEX(''-'',S.DESCR,CHARINDEX(''-'', S.DESCR, CHARINDEX(''-'',S.DESCR)+1)+1)-CHARINDEX(''-'', S.DESCR, CHARINDEX(''-'',S.DESCR)+1)-1) '
  --           + ' ELSE SUBSTRING(S.DESCR, CHARINDEX(''-'', S.DESCR, CHARINDEX(''-'',S.DESCR)+1)+1, '
  --           + ' LEN(S.DESCR)-CHARINDEX(''-'', S.DESCR, CHARINDEX(''-'',S.DESCR)+1)+1) END,' 
  SET @c_SQLJOIN = +' SELECT s.style,CONCAT(ISNULL(SIF.ExtendedField01,''''), ISNULL(SIF.ExtendedField02,'''')),s.color,'
             --+ ' SUBSTRING(s.DESCR, CHARINDEX(''-'', S.DESCR, CHARINDEX(''-'',S.DESCR)+1)+1, CHARINDEX(''-'',S.DESCR, '
             --+ ' CHARINDEX(''-'', S.DESCR, CHARINDEX(''-'',S.DESCR)+1)+1)-CHARINDEX(''-'', S.DESCR, CHARINDEX(''-'',S.DESCR)+1)-1),' --4   
             + ' CONCAT(ISNULL(SIF.ExtendedField03,''''), ISNULL(SIF.ExtendedField04,'''')),'   --CS02 END 
             + ' s.size,s.sku,'''','''','''','''', '      --10  
             + ' '''','''','''','''','''','     --15       
             + CHAR(13) +      
             + ' '''','''','''','''','''','         --20      
             + ' '''','''','''','''','''','''','''','''','''','''','  --30  
             + ' '''','''','''','''','''','''','''','''','''','''','   --40       
             + ' '''','''','''','''','''','''','''','''','''','''', '  --50       
             + ' '''','''','''','''','''','''','''','''','''','''' '   --60  
             + ' FROM SKU S WITH (NOLOCK) '
             + ' JOIN SKUINFO SIF WITH (NOLOCK) ON SIF.Storerkey = S.Storerkey AND SIF.sku = S.sku '    --CS02
             + ' WHERE S.storerkey = @c_Sparm01 '
          --   + ' AND S.sku = @c_Sparm02 OR s.sku = @c_Sparm04 OR s.sku = @c_Sparm05'   
          --   + ' ORDER BY S.sku'     
 END 
 ELSE
 BEGIN
--CS02 START
 --SET @c_SQLJOIN = +' SELECT TOP 1 s.style,SUBSTRING(s.DESCR, CHARINDEX(''-'',s.DESCR)+1, '
 --            + ' CHARINDEX(''-'',s.DESCR,CHARINDEX(''-'',s.DESCR)+1)-CHARINDEX(''-'',s.DESCR)-1),s.color,'
 --            --+ ' SUBSTRING(s.DESCR, CHARINDEX(''-'', S.DESCR, CHARINDEX(''-'',S.DESCR)+1)+1, CHARINDEX(''-'',S.DESCR, '
 --            --+ ' CHARINDEX(''-'', S.DESCR, CHARINDEX(''-'',S.DESCR)+1)+1)-CHARINDEX(''-'', S.DESCR, CHARINDEX(''-'',S.DESCR)+1)-1),' --4   
 --            + ' CASE WHEN CHARINDEX(''-'',S.DESCR,CHARINDEX(''-'', S.DESCR, CHARINDEX(''-'',S.DESCR)+1)+1) <> 0 '
 --            + ' THEN SUBSTRING(S.DESCR, CHARINDEX(''-'', S.DESCR, CHARINDEX(''-'',S.DESCR)+1)+1, '
 --            + ' CHARINDEX(''-'',S.DESCR,CHARINDEX(''-'', S.DESCR, CHARINDEX(''-'',S.DESCR)+1)+1)-CHARINDEX(''-'', S.DESCR, CHARINDEX(''-'',S.DESCR)+1)-1) '
 --            + ' ELSE SUBSTRING(S.DESCR, CHARINDEX(''-'', S.DESCR, CHARINDEX(''-'',S.DESCR)+1)+1, '
 --            + ' LEN(S.DESCR)-CHARINDEX(''-'', S.DESCR, CHARINDEX(''-'',S.DESCR)+1)+1) END,' 
  SET @c_SQLJOIN = +' SELECT TOP 1 s.style,CONCAT(ISNULL(SIF.ExtendedField01,''''), ISNULL(SIF.ExtendedField02,'''')),s.color,'
             --+ ' SUBSTRING(s.DESCR, CHARINDEX(''-'', S.DESCR, CHARINDEX(''-'',S.DESCR)+1)+1, CHARINDEX(''-'',S.DESCR, '
             --+ ' CHARINDEX(''-'', S.DESCR, CHARINDEX(''-'',S.DESCR)+1)+1)-CHARINDEX(''-'', S.DESCR, CHARINDEX(''-'',S.DESCR)+1)-1),' --4   
             + ' CONCAT(ISNULL(SIF.ExtendedField03,''''), ISNULL(SIF.ExtendedField04,'''')),'   --CS02 END 
             + ' s.size,s.sku,'''','''','''','''', '      --10  
             + ' '''','''','''','''','''','     --15       
             + CHAR(13) +      
             + ' '''','''','''','''','''','         --20      
             + ' '''','''','''','''','''','''','''','''','''','''','  --30  
             + ' '''','''','''','''','''','''','''','''','''','''','   --40       
             + ' '''','''','''','''','''','''','''','''','''','''', '  --50       
             + ' '''','''','''','''','''','''','''','''','''','''' '   --60  
             + ' FROM SKU S WITH (NOLOCK) '
             + ' JOIN SKUINFO SIF WITH (NOLOCK) ON SIF.Storerkey = S.Storerkey AND SIF.sku = S.sku '    --CS02
             + ' WHERE S.storerkey = @c_Sparm01 '
         --    + ' AND S.sku = @c_Sparm02 '      

 END  --CS01 END       
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

SET @c_SQL = @c_SQL + @c_SQLJOIN + CHAR(13) + @c_condition1 + CHAR(13) + @c_orderby

   
   SET @c_ExecArguments = N'  @c_Sparm01         NVARCHAR(80)'  
                         + ' ,@c_Sparm02         NVARCHAR(80)'  
                         + ' ,@c_Sparm04         NVARCHAR(80)'    --CS01
                         + ' ,@c_Sparm05         NVARCHAR(80)'    --CS01
                               
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @c_Sparm01
                        , @c_Sparm02    
                        , @c_Sparm04             --CS01 
                        , @c_Sparm05             --CS01
                
        
      IF @b_debug=1        
      BEGIN          
        PRINT @c_SQL          
      END        
      IF @b_debug=1        
      BEGIN        
        SELECT * FROM #Result (nolock)        
      END   
      
   WHILE @n_copy > 1
   BEGIN
      INSERT INTO #Result
      (
         -- ID -- this column value is auto-generated
         Col01,
         Col02,
         Col03,
         Col04,
         Col05,
         Col06,
         Col07,
         Col08,
         Col09,
         Col10,
         Col11,
         Col12,
         Col13,
         Col14,
         Col15,
         Col16,
         Col17,
         Col18,
         Col19,
         Col20,
         Col21,
         Col22,
         Col23,
         Col24,
         Col25,
         Col26,
         Col27,
         Col28,
         Col29,
         Col30,
         Col31,
         Col32,
         Col33,
         Col34,
         Col35,
         Col36,
         Col37,
         Col38,
         Col39,
         Col40,
         Col41,
         Col42,
         Col43,
         Col44,
         Col45,
         Col46,
         Col47,
         Col48,
         Col49,
         Col50,
         Col51,
         Col52,
         Col53,
         Col54,
         Col55,
         Col56,
         Col57,
         Col58,
         Col59,
         Col60
      )
      SELECT TOP 1 Col01,
         Col02,
         Col03,
         Col04,
         Col05,
         Col06,
         Col07,
         Col08,
         Col09,
         Col10,
         Col11,
         Col12,
         Col13,
         Col14,
         Col15,
         Col16,
         Col17,
         Col18,
         Col19,
         Col20,
         Col21,
         Col22,
         Col23,
         Col24,
         Col25,
         Col26,
         Col27,
         Col28,
         Col29,
         Col30,
         Col31,
         Col32,
         Col33,
         Col34,
         Col35,
         Col36,
         Col37,
         Col38,
         Col39,
         Col40,
         Col41,
         Col42,
         Col43,
         Col44,
         Col45,
         Col46,
         Col47,
         Col48,
         Col49,
         Col50,
         Col51,
         Col52,
         Col53,
         Col54,
         Col55,
         Col56,
         Col57,
         Col58,
         Col59,
         Col60
      FROM #Result AS r
      ORDER BY r.ID
      
      SET @n_copy = @n_copy - 1
   END 
  --CS03 START
   IF @n_copy = 1 AND @c_Sparm02 = @c_Sparm04
   BEGIN   

     INSERT INTO #Result
     (
         Col01,
         Col02,
         Col03,
         Col04,
         Col05,
         Col06,
         Col07,
         Col08,
         Col09,
         Col10,
         Col11,
         Col12,
         Col13,
         Col14,
         Col15,
         Col16,
         Col17,
         Col18,
         Col19,
         Col20,
         Col21,
         Col22,
         Col23,
         Col24,
         Col25,
         Col26,
         Col27,
         Col28,
         Col29,
         Col30,
         Col31,
         Col32,
         Col33,
         Col34,
         Col35,
         Col36,
         Col37,
         Col38,
         Col39,
         Col40,
         Col41,
         Col42,
         Col43,
         Col44,
         Col45,
         Col46,
         Col47,
         Col48,
         Col49,
         Col50,
         Col51,
         Col52,
         Col53,
         Col54,
         Col55,
         Col56,
         Col57,
         Col58,
         Col59,
         Col60
     )
     SELECT TOP 1 Col01,
         Col02,
         Col03,
         Col04,
         Col05,
         Col06,
         Col07,
         Col08,
         Col09,
         Col10,
         Col11,
         Col12,
         Col13,
         Col14,
         Col15,
         Col16,
         Col17,
         Col18,
         Col19,
         Col20,
         Col21,
         Col22,
         Col23,
         Col24,
         Col25,
         Col26,
         Col27,
         Col28,
         Col29,
         Col30,
         Col31,
         Col32,
         Col33,
         Col34,
         Col35,
         Col36,
         Col37,
         Col38,
         Col39,
         Col40,
         Col41,
         Col42,
         Col43,
         Col44,
         Col45,
         Col46,
         Col47,
         Col48,
         Col49,
         Col50,
         Col51,
         Col52,
         Col53,
         Col54,
         Col55,
         Col56,
         Col57,
         Col58,
         Col59,
         Col60
      FROM #Result AS r
      WHERE col06=@c_Sparm02  

   END
  --CS03 END    
     
      SELECT * FROM #Result (nolock)   
            
EXIT_SP:    
  
   SET @d_Trace_EndTime = GETDATE()  
   SET @c_UserName = SUSER_SNAME()  
     
                                  
END -- procedure   




GO
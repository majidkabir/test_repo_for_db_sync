SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_BT_Bartender_CN_UCCLabel_01_UA                                */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2018-02-01 1.0  CSCHONG    Created (WMS-3883)                              */ 
/* 2022-02-27 1.1  MINGLE     add new col5&6(ML01) (WMS-18936)                */
/******************************************************************************/                
                  
CREATE   PROC [dbo].[isp_BT_Bartender_CN_UCCLabel_01_UA]                      
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
 --  SET ANSI_WARNINGS OFF                    --CS01           
                              
   DECLARE                  
      @c_ReceiptKey      NVARCHAR(10),                    
      @c_sku             NVARCHAR(20),                         
      @n_intFlag         INT,     
      @n_CntRec          INT,    
      @c_SQL             NVARCHAR(4000),        
      @c_SQLSORT         NVARCHAR(4000),        
      @c_SQLJOIN         NVARCHAR(4000)      
    
  DECLARE   @d_Trace_StartTime   DATETIME,   
				@d_Trace_EndTime    DATETIME,  
				@c_Trace_ModuleName NVARCHAR(20),   
				@d_Trace_Step1      DATETIME,   
				@c_Trace_Step1      NVARCHAR(20),  
				@c_UserName         NVARCHAR(20),
				@c_SKU01            NVARCHAR(20),         
				@c_SKU02            NVARCHAR(20),          
				@c_SKU03            NVARCHAR(20),        
				@c_SKU04            NVARCHAR(20),        
				@c_SKU05            NVARCHAR(20),        
				@c_SKUQty01         NVARCHAR(10),        
				@c_SKUQty02         NVARCHAR(10),         
				@c_SKUQty03         NVARCHAR(10),         
				@c_SKUQty04         NVARCHAR(10),         
				@c_SKUQty05         NVARCHAR(10) ,
				@n_TTLpage          INT,        
				@n_CurrentPage      INT,
				@n_MaxLine          INT  ,
				@c_LLIId            NVARCHAR(80) ,
				@c_storerkey        NVARCHAR(20) ,
				@n_skuqty           INT, 
				@c_ExecStatements   NVARCHAR(4000),   
            @c_ExecArguments    NVARCHAR(4000)    
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
    -- SET RowNo = 0             
    SET @c_SQL = ''     
    SET @n_CurrentPage = 1
    SET @n_TTLpage =1     
    SET @n_MaxLine = 5    
    SET @n_CntRec = 1  
    SET @n_intFlag = 1        
              
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
      
      CREATE TABLE [#TEMPLLISKU03] (                   
      [ID]          [INT] IDENTITY(1,1) NOT NULL,                                      
      [Storerkey]   [NVARCHAR] (20) NULL,  
      [LLI_ID]        [NVARCHAR] (20) NULL,       
      [SKU]         [NVARCHAR] (20) NULL,           
      [Qty]         INT , 
      [Retrieve]    [NVARCHAR] (1) default 'N')         
  	        
  SET @c_SQLJOIN = +' SELECT DISTINCT U.uccno,u.sku,s.ALTSKU,s.packkey,SUSER_SNAME(),'+ CHAR(13)      --5  --ML01    
             + ' convert(varchar, getdate(), 20),'''','''','''','''','     --10                            --ML01
             + ' '''','''','''','''','''','     --15  
             + ' '''','''','''','''','''','     --20       
             + CHAR(13) +      
             + ' '''','''','''','''','''','''','''','''','''','''','  --30  
             + ' '''','''','''','''','''','''','''','''','''','''','   --40       
             + ' '''','''','''','''','''','''','''','''','''','''', '  --50       
             + ' '''','''','''','''','''','''','''','''','''',''O'' '   --60          
             + CHAR(13) +                  
             + ' FROM UCC AS U WITH (NOLOCK)'   
             + ' JOIN SKU AS s WITH (NOLOCK) ON s.SKU=u.Sku AND s.StorerKey=u.StorerKey'
             + ' WHERE U.UCCNo = @c_Sparm01 AND'    
             + ' U.Storerkey= @c_Sparm02 '   

          
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
   
   SET @c_ExecArguments = N'@c_Sparm01      NVARCHAR(80)'    
                     + ', @c_Sparm02        NVARCHAR(80) '    

                                          
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @c_Sparm01    
                        , @c_Sparm02    
        
    --EXEC sp_executesql @c_SQL          
        
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
      @c_TraceName = 'isp_BT_Bartender_CN_UCCLabel_01_UA',  
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
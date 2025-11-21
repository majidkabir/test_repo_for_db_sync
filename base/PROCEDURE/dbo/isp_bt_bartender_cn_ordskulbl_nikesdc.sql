SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/********************************************************************************/                   
/* Copyright: LFL                                                               */                   
/* Purpose: isp_BT_Bartender_CN_ORDSKULBL_NIKESDC                               */                   
/*                                                                              */                   
/* Modifications log:                                                           */                   
/*                                                                              */                   
/* Date       Rev  Author     Purposes                                          */                   
/* 2021-08-12 1.0  WLChooi    Created (WMS-17662) - DevOps Combine Script       */
/********************************************************************************/                  
                    
CREATE PROC [dbo].[isp_BT_Bartender_CN_ORDSKULBL_NIKESDC]                        
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
      @n_intFlag         INT,       
      @n_CntRec          INT,      
      @c_SQL             NVARCHAR(4000),          
      @c_SQLSORT         NVARCHAR(4000),          
      @c_SQLJOIN         NVARCHAR(4000),  
      @c_ExecStatements  NVARCHAR(4000),         
      @c_ExecArguments   NVARCHAR(4000),  
      
      @n_TTLpage         INT,            
      @n_CurrentPage     INT,    
      @n_MaxLine         INT
      
  DECLARE  @d_Trace_StartTime   DATETIME,     
           @d_Trace_EndTime     DATETIME,    
           @c_Trace_ModuleName  NVARCHAR(20),     
           @d_Trace_Step1       DATETIME,     
           @c_Trace_Step1       NVARCHAR(20),    
           @c_UserName          NVARCHAR(20),
           @n_ExtendedPrice     FLOAT = 0.00,
           @n_UnitPrice         FLOAT = 0.00,
           @c_ExtendedPrice     NVARCHAR(5) = ''              
    
   SET @d_Trace_StartTime = GETDATE()    
   SET @c_Trace_ModuleName = ''   
     
   SET @n_CurrentPage = 1    
   SET @n_TTLpage =1         
   SET @n_MaxLine = 8       
   SET @n_CntRec = 1      
   SET @n_intFlag = 1     
                   
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
   SELECT @n_ExtendedPrice = ISNULL(OD.ExtendedPrice, 0.00)
        , @n_UnitPrice     = ISNULL(OD.UnitPrice, 0.00)
   FROM ORDERDETAIL OD (NOLOCK)
   WHERE OD.OrderKey = @c_Sparm03
   AND OD.StorerKey = @c_Sparm01
   AND OD.SKU = @c_Sparm02

   IF ISNULL(@n_ExtendedPrice, 0.00) = 0 OR ISNULL(@n_UnitPrice, 0.00) = 0   --Skip Printing if UnitPrice or ExtendedPrice is NULL or 0
   BEGIN
      GOTO QUIT_SP
   END

   SET @c_ExtendedPrice = RIGHT(REPLICATE('0', 4) + CAST(@n_ExtendedPrice AS NVARCHAR), 4)

   SET @c_SQLJOIN = + ' SELECT TOP 1 TRIM(ISNULL(CL.Code,'''')) + CAST(@c_ExtendedPrice AS NVARCHAR), ' + CHAR(13) --1
                    + ' CAST(@n_UnitPrice AS NVARCHAR), '''', '''', '''', ' + CHAR(13) --5
                    + ' '''', '''', '''', '''', '''', '  + CHAR(13) --10      
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13) --20         
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13) --30     
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13) --40  
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13) --50        
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', OH.Orderkey, ''CN'' '   --60            
                    + CHAR(13) +              
                    + ' FROM ORDERS OH WITH (NOLOCK)' + CHAR(13)  
                    + ' JOIN CODELKUP CL WITH (NOLOCK) ON CL.Listname = ''NKLABREF'' AND CL.Storerkey = OH.Storerkey '   + CHAR(13)  
                    + '                                AND CL.Long = OH.Consigneekey '   + CHAR(13) 
                    + ' WHERE OH.Orderkey =  @c_Sparm03 '          

   IF @b_debug=1          
   BEGIN          
      PRINT @c_SQLJOIN            
   END                  
                
   SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +             
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +             
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +             
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +             
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +             
             +',Col55,Col56,Col57,Col58,Col59,Col60) '    
                  
   SET @c_SQL = @c_SQL + @c_SQLJOIN                
                                  
  
   SET @c_ExecArguments =    N'  @c_Sparm01         NVARCHAR(80) '      
                            + ', @c_Sparm02         NVARCHAR(80) '       
                            + ', @c_Sparm03         NVARCHAR(80) '  
                            + ', @c_ExtendedPrice   NVARCHAR(80) ' 
                            + ', @n_UnitPrice       FLOAT        ' 
          
   EXEC sp_ExecuteSql     @c_SQL       
                        , @c_ExecArguments      
                        , @c_Sparm01      
                        , @c_Sparm02    
                        , @c_Sparm03  
                        , @c_ExtendedPrice
                        , @n_UnitPrice
          
   IF @b_debug=1          
   BEGIN            
      PRINT @c_SQL            
   END         
  
QUIT_SP:  
   SELECT * FROM #Result (nolock)       
   ORDER BY ID     
          
END -- procedure     

GO
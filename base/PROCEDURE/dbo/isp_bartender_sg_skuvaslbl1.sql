SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: BarTender sku label                                               */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2023-05-10 1.0  CSCHONG    Devops scripts combine - Created(WMS-22454)     */                 
/******************************************************************************/                
                  
CREATE   PROC [dbo].[isp_Bartender_SG_SKUVASLBL1]                      
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
      @c_SQLJOIN         NVARCHAR(4000),
      @c_OHNotes         NVARCHAR(4000), 
      @c_GetOHNotes      NVARCHAR(4000), 
      @n_SeqNo           INT,
      @c_ColValue        NVARCHAR(250)         
    
  DECLARE  @d_Trace_StartTime   DATETIME,   
           @d_Trace_EndTime     DATETIME,  
           @c_Trace_ModuleName  NVARCHAR(20),   
           @d_Trace_Step1       DATETIME,   
           @c_Trace_Step1       NVARCHAR(20),  
           @c_UserName          NVARCHAR(20),
           @c_ExecArguments     NVARCHAR(4000),
           @c_col03             NVARCHAR(80) = '',
           @c_col04             NVARCHAR(80) = '',
           @c_col05             NVARCHAR(80) = '',
           @c_col06             NVARCHAR(80) = '',
           @c_col07             NVARCHAR(80) = '',
           @c_col08             NVARCHAR(80) = '',
           @c_col09             NVARCHAR(80) = '',
           @c_col10             NVARCHAR(80) = '',
           @c_DelimiterSign     NVARCHAR(5),
           @c_Temp1DelimiterSign     NVARCHAR(5),       
           @c_Temp2DelimiterSign     NVARCHAR(5)        
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
    -- SET RowNo = 0             
    SET @c_SQL = ''       
          
    --SET @c_DelimiterSign = '\\'
    SET @c_DelimiterSign = '|'    
    SET @c_Temp1DelimiterSign = '\n'    
    SET @c_Temp2DelimiterSign = '\#' 
              
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
        
     IF ISNULL(@c_Sparm01,'') = ''
     BEGIN
            GOTO EXIT_SP
     END      
        

     SELECT TOP 1 @c_ExternOrderKey = oh.ExternOrderKey
                 ,@c_OHNotes = ISNULL(oh.notes,'')
     FROM ORDERS OH WITH (NOLOCK)
     WHERE OH.Orderkey = @c_Sparm02
     AND OH.StorerKey = @c_Sparm01

 
     SELECT @c_OHNotes = REPLACE(@c_OHNotes, @c_DelimiterSign, @c_Temp2DelimiterSign) --replace existing '|' char with '\#'  
     SELECT @c_OHNotes = REPLACE(@c_OHNotes, @c_Temp1DelimiterSign, @c_DelimiterSign) --replace new line char '\n' char with '|'   

     DECLARE C_DelimSplit CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
     SELECT SeqNo, ColValue 
     FROM dbo.fnc_DelimSplit(@c_DelimiterSign,@c_OHNotes)
     
     OPEN C_DelimSplit
     FETCH NEXT FROM C_DelimSplit INTO @n_SeqNo, @c_ColValue

     WHILE (@@FETCH_STATUS=0) 
     BEGIN

     SELECT @c_ColValue = REPLACE(@c_ColValue, @c_Temp2DelimiterSign, @c_DelimiterSign) --replace '\#' back to '|'  
           
     IF @n_SeqNo = 1
     BEGIN
      SET @c_col03 = @c_ColValue
     END
     ELSE IF @n_SeqNo = 2
      BEGIN
      SET @c_col04 = @c_ColValue
     END
     ELSE IF @n_SeqNo = 3
      BEGIN
      SET @c_col05 = @c_ColValue
     END
     ELSE IF @n_SeqNo = 4
      BEGIN
      SET @c_col06 = @c_ColValue
     END
     ELSE IF @n_SeqNo = 5
      BEGIN
      SET @c_col07 = @c_ColValue
     END
     ELSE IF @n_SeqNo = 6
      BEGIN
      SET @c_col08 = @c_ColValue
     END
       

     FETCH NEXT FROM C_DelimSplit INTO @n_SeqNo, @c_ColValue
     END -- WHILE (@@FETCH_STATUS <> -1) AND @n_Continue <> 3
     
     CLOSE C_DelimSplit
     DEALLOCATE C_DelimSplit

               
     
    INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09           
                        ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22           
                        ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34      
                        ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44           
                        ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54          
                        ,Col55,Col56,Col57,Col58,Col59,Col60)       
    SELECT TOP 1 @c_ExternOrderKey,'',@c_col03,@c_col04,@c_col05, @c_col06,@c_col07,@c_col08,@c_col09,@c_col10, 
              '','','','','','','','','','',  --20      
              '','','','','','','','','','',  --30  
              '','','','','','','','','','',   --40       
              '','','','','','','','','','',   --50       
              '','','','','','','','','',''    --60  
        
      IF @b_debug='1'        
      BEGIN          
        PRINT @c_SQL          
      END        
      IF @b_debug='1'       
      BEGIN        
        SELECT * FROM #Result (nolock)        
      END           
     
      SELECT * FROM #Result (nolock)   
            
EXIT_SP:    
  
   SET @d_Trace_EndTime = GETDATE()  
   SET @c_UserName = SUSER_SNAME()  
                                      
END -- procedure   



GO
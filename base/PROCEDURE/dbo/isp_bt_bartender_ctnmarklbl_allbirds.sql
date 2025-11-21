SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_BT_Bartender_Shipper_Label_Allbirds(WMS-8283)                 */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_BT_Bartender_CTNMARKLBL_Allbirds]                      
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
      @c_caseid          NVARCHAR(80),                    
      @c_sku             NVARCHAR(20),                         
      @n_intFlag         INT,     
      @n_CntRec          INT,    
      @c_SQL             NVARCHAR(4000),        
      @c_SQLSORT         NVARCHAR(4000),        
      @c_SQLJOIN         NVARCHAR(4000),
      @c_col02           NVARCHAR(80),
      @c_col03           NVARCHAR(20),
      @c_ExecStatements  NVARCHAR(4000),      
      @c_ExecArguments   NVARCHAR(4000)     
      
      
declare   @c_orderkey      NVARCHAR(20),
          @c_ORDLineNo     NVARCHAR(10),
          @c_note          NVARCHAR(250),
          @n_MaxRec        INT,
          @c_note1_1       NVARCHAR(250),
          @c_note1_2       NVARCHAR(250),
          @c_note1_3       NVARCHAR(250),
          @c_PreORDLineNo  NVARCHAR(10),
          @n_lineCnt       INT,
          @c_lastRec       NVARCHAR(5),
          @c_note1         NVARCHAR(20),
          @n_recgrp        INT      
    
  DECLARE  @d_Trace_StartTime  DATETIME,   
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),   
           @d_Trace_Step1      DATETIME,   
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20),
           @c_SKU01            NVARCHAR(80),         
           @c_SKU02            NVARCHAR(80),          
           @c_SKU03            NVARCHAR(80), 
           @c_SKU04            NVARCHAR(80), 
           @c_SKU05            NVARCHAR(80),         
           @c_SKU06            NVARCHAR(80),          
           @c_SKU07            NVARCHAR(80), 
           @c_SKU08            NVARCHAR(80), 
           @c_SKU09            NVARCHAR(80), 
           @c_SKU10            NVARCHAR(80),
           @n_line01           INT,
           @n_line02           INT,
           @n_line03           INT,
           @n_line04           INT,
           @n_line05           INT,
           @n_line06           INT,
           @n_line07           INT,
           @n_line08           INT,
           @n_line09           INT,
           @n_line10           INT,  
           @n_Qty01           INT,
           @n_Qty02           INT,
           @n_Qty03           INT,
           @n_Qty04           INT,
           @n_Qty05           INT,
           @n_Qty06           INT,
           @n_Qty07           INT,
           @n_Qty08           INT,
           @n_Qty09           INT,
           @n_Qty10           INT,            
           @c_note1_1_01       NVARCHAR(80),         
           @c_note1_1_02       NVARCHAR(80),          
           @c_note1_1_03       NVARCHAR(80), 
           @c_note1_1_04       NVARCHAR(80),        
           @c_note1_2_01       NVARCHAR(80),
           @c_note1_2_02       NVARCHAR(80),
           @c_note1_2_03       NVARCHAR(80),
           @c_note1_2_04       NVARCHAR(80),
           @c_note1_3_01       NVARCHAR(80),
           @c_note1_3_02       NVARCHAR(80),
           @c_note1_3_03       NVARCHAR(80),
           @c_note1_3_04       NVARCHAR(80),
           @n_TTLpage          INT,        
           @n_CurrentPage      INT,
           @n_MaxLine          INT
            
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
    -- SET RowNo = 0             
    SET @c_SQL = ''     
    SET @n_CurrentPage = 1
    SET @n_TTLpage =1     
    SET @n_MaxLine = 10   
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
    
           
    INSERT INTO #Result(Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09,Col10,
                  Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,
                  Col21,Col22,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,
                  Col31,Col32,Col33,Col34,Col35,Col36,Col37,Col38,Col39,Col40,
                  Col41,Col42,Col43,Col44,Col45,Col46,Col47,Col48,Col49,Col50,
                  Col51,Col52,Col53,Col54,Col55,Col56,Col57,Col58,Col59,Col60)
    SELECT substring(OH.notes,1,40),substring(OH.notes,41,40),substring(OH.notes,81,40),ISNULL(OH.M_Company,''),
           '','','','','','',
         '','','','','','','','','','',
         '','','','','','','','','','',
         '','','','','','','','','','',
         '','','','','','','','','','', 
         '','','','','','','','','',OH.Externorderkey  
   FROM ORDERS OH (NOLOCK)
   WHERE OH.Orderkey = @c_Sparm02
   AND ISNULL(OH.notes,'') <> ''
         
   IF @b_debug=1        
   BEGIN        
      SELECT * FROM #Result (nolock)        
   END        
          
SELECT * FROM #Result (nolock)        
        
EXIT_SP:    
  
   SET @d_Trace_EndTime = GETDATE()  
   SET @c_UserName = SUSER_SNAME()  
                                     
END -- procedure   

GO
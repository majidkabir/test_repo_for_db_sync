SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*************************************************************************/
/* Store procedure: isp_WS_SSCCGen01                                     */
/* Creation Date: 2024-09-02                                             */
/* Copyright: Maersk                                                     */
/* Written by: WSE016                                                    */
/*                                                                       */
/* Purpose: ?                                                            */
/*        :                                                              */
/* Called By: Fn593 - RDT Re-Print                                       */
/*          :                                                            */
/* PVCS Version: 1.0                                                     */
/* Version: 1.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Purposes                                        */
/* 02/09/2024   WSE016   Created combine script to get data for SSCC Gen */
/*                                                                       */
/*************************************************************************/        
                
CREATE    PROCEDURE [dbo].[isp_WS_SSCCGen01]                     
(  @c_Sparm1            NVARCHAR(250) = NULL,            
   @c_Sparm2            NVARCHAR(250) = NULL,            
   @c_Sparm3            NVARCHAR(250) = NULL,            
   @c_Sparm4            NVARCHAR(250) = NULL,            
   @c_Sparm5            NVARCHAR(250) = NULL,            
   @c_Sparm6            NVARCHAR(250) = NULL,            
   @c_Sparm7            NVARCHAR(250) = NULL,            
   @c_Sparm8            NVARCHAR(250) = NULL,            
   @c_Sparm9            NVARCHAR(250) = NULL,            
   @c_Sparm10           NVARCHAR(250) = NULL,      
   @b_debug             INT = 0                       
)                    
AS                    
BEGIN                    
   SET NOCOUNT ON               
   SET ANSI_NULLS OFF              
   SET QUOTED_IDENTIFIER OFF               
   SET CONCAT_NULL_YIELDS_NULL OFF              

   DECLARE
        @SSCCGen NVARCHAR(max),
		 @n_copy   INT,
		 @c_sql    NVARCHAR(MAX) 
    
      
   
    SET @n_copy = 0
    SET @n_copy = CAST (@c_Sparm4 AS INT)
          
            
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
     
 
	-- Get the Label Info.	 
 SELECT @SSCCGen = 
UDF01 
+ (case when udf02 <> '' then udf02 else'' end)
+ UDF03
+ UDF04
+ UDF05
+ RIGHT('0000000000' + CONVERT(VARCHAR(10),short), 10)
 from Codelkup  WITH (NOLOCK) where storerkey = 'HRPUMA' and LISTNAME = 'WS_SSCCGen';
	

 
	INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05,Col06,Col07,Col08,Col09,Col10
						,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20         
						,Col21,Col22,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30
						,Col31,Col32,Col33,Col34,Col35,Col36,Col37,Col38,Col39,Col40
						,Col41,Col42,Col43,Col44,Col45,Col46,Col47,Col48,Col49,Col50
						,Col51,Col52,Col53,Col54,Col55,Col56,Col57,Col58,Col59,Col60)     
     VALUES(
		@SSCCGen, '', '', '', '', '', '', '', '','', --10
		'','','','','','','','','','',--20
		'','','','', '','','','','','',	--30
		'','','','','','','','','','',	--40
		'','','','','','','','','','',	--50
		'','','','','','','','','',''	--60
			) 
       
   IF @b_debug=1      
   BEGIN        
      PRINT @c_SQL        
   END      
   IF @b_debug=1      
   BEGIN      
      SELECT * FROM #Result (nolock)      
   END      

EXIT_SP:  

        
 
select * from #result WITH (NOLOCK)
                                
END -- procedure  
 
 


GO
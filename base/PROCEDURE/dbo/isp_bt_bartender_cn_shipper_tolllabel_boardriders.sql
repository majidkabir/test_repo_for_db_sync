SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/******************************************************************************/                   
/* Copyright: IDS                                                             */                   
/* Purpose: isp_BT_Bartender_CN_Shipper_TollLabel_BoardRiders                 */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date        Rev  Author      Purposes                                      */  
/* 13-MAY-2019 1.0  WLCHOOI     Created (WMS-9043)                            */  
/* 23-Mar-2022 1.1  WLChooi     DevOps Combine Script                         */
/* 23-Mar-2022 1.1  WLChooi     WMS-18285 - Add Col28 (WL01)                  */
/******************************************************************************/                  
                    
CREATE PROC [dbo].[isp_BT_Bartender_CN_Shipper_TollLabel_BoardRiders]                        
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
      @c_sku             NVARCHAR(80),                           
      @n_intFlag         INT,       
      @n_CntRec          INT,      
      @c_SQL             NVARCHAR(4000),          
      @c_SQLSORT         NVARCHAR(4000),          
      @c_SQLJOIN         NVARCHAR(4000)
      
   DECLARE @d_Trace_StartTime   DATETIME,     
           @d_Trace_EndTime    DATETIME,    
           @c_Trace_ModuleName NVARCHAR(20),     
           @d_Trace_Step1      DATETIME,     
           @c_Trace_Step1      NVARCHAR(20),    
           @c_UserName         NVARCHAR(20),      
           @n_CurrentPage      INT,  
           @n_MaxLine          INT  ,  
           @c_labelno          NVARCHAR(20) ,  
           @c_orderkey         NVARCHAR(20) ,  
           @n_skuqty           INT ,  
           @n_skurqty          INT ,  
           @c_cartonno         NVARCHAR(5),  
           @n_loopno           INT,  
           @c_LastRec          NVARCHAR(1),  
           @c_ExecStatements   NVARCHAR(4000),      
           @c_ExecArguments    NVARCHAR(4000),
           @c_Col25            NVARCHAR(4000),
           @c_Col26            NVARCHAR(4000),
           @c_Col27            NVARCHAR(4000),
           --@n_Sum              FLOAT
           @n_Sum              DECIMAL(10,1)
    
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
         
   SET @c_SQLJOIN = N' SELECT DISTINCT LTRIM(RTRIM(ISNULL(CL1.UDF04,''''))) + RIGHT(LTRIM(RTRIM(ORD.ExternOrderKey)),7), SUBSTRING(ISNULL(CL1.Long,''''),1,80), ' + CHAR(13) --2
                  +  ' SUBSTRING(ISNULL(F.DESCR,''''),1,80), F.Address1, F.Address2, ' + CHAR(13) --5
                  +  ' SUBSTRING(ISNULL(F.City,'''') + '' '' + ISNULL(F.Country,'''') + '' '' + ISNULL(F.Zip,'''') ,1,80), ' + CHAR(13) --6
                  +  ' ORD.C_Company, ORD.C_Address1, ORD.C_Address2, ORD.C_Address3, ' + CHAR(13) --10
                  +  ' ORD.C_City, ORD.C_State, ORD.C_Zip, ISNULL(CL2.CODE2,''''), ISNULL(CL1.Short,''''), ISNULL(CL1.CODE2,''''), ' + CHAR(13) --16
                  +  ' SUBSTRING(PD.LabelNo,11,9), ISNULL(CL2.Short,''''), ORD.Ordergroup, SUBSTRING(ISNULL(ORD.NOTES,''''),1,80), ' + CHAR(13) --20
                  +  ' ORD.ExternOrderKey, ORD.BuyerPO + ORD.UserDefine05, SUBSTRING(ISNULL(CL1.DESCRIPTION,''''),1,80), SUBSTRING(ORD.Notes2,1,80), ' + CHAR(13) --24

                  +  ' LEFT( (LEFT(LTRIM(RTRIM(ISNULL(PD.LabelNo,''''))) + REPLICATE('' '',80), 32) ' --25
                  +  ' + LEFT(LTRIM(RTRIM(ISNULL(CL1.Notes,''''))) + REPLICATE('' '',80), 2) ' --25
                  +  ' + LEFT(LTRIM(RTRIM(ISNULL(ORD.C_Company,''''))) + REPLICATE('' '',80), 40) ' --25
                  +  ' + SPACE(10)),74), ' --25
                  + CHAR(13)
                  +  ' LEFT( (LEFT(LTRIM(RTRIM(ISNULL(ORD.C_Address1,''''))) + REPLICATE('' '',80), 30)  ' --26
                  +  ' + LEFT(LTRIM(RTRIM(ISNULL(ORD.C_Address2,''''))) + '' '' +  LTRIM(RTRIM(ISNULL(ORD.C_Address3,''''))) + REPLICATE('' '',80), 30) ' --26
                  +  ' + SPACE(20)),60), ' --26 
                  + CHAR(13)
                  +  ' LEFT( (LEFT(LTRIM(RTRIM(ISNULL(ORD.C_City,''''))) + REPLICATE('' '',80), 30) ' --27
                  +  ' + RIGHT(REPLICATE(''0'',4) + LTRIM(RTRIM(ISNULL(ORD.C_Zip,''''))),4) + SPACE(2)  ' --27
                  +  ' + LEFT(LTRIM(RTRIM(ISNULL(CL1.UDF03,''''))) + REPLICATE('' '',80), 10) + ''S'' ' --27
                  +  ' + SPACE(40)),80), ' --27
                  + CHAR(13)
                  +  ' ISNULL(CL1.UDF05,''''), '''', '''', ' + CHAR(13) --30   --WL01
                  +  ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13) --40
                  +  ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13) --50
                  +  ' '''', '''', '''', '''', '''', '''', PH.Pickslipno, @c_Sparm01, ORD.Orderkey, ''CN'' ' + CHAR(13) --60
                  +  ' FROM PACKDETAIL PD (NOLOCK) ' + CHAR(13)
                  +  ' JOIN PACKHEADER PH (NOLOCK) ON PH.PICKSLIPNO = PD.PICKSLIPNO ' + CHAR(13)
                  +  ' JOIN ORDERS ORD (NOLOCK) ON PH.ORDERKEY = ORD.ORDERKEY ' + CHAR(13)
                  +  ' JOIN FACILITY F (NOLOCK) ON F.FACILITY = ORD.FACILITY ' + CHAR(13)
                  +  ' LEFT JOIN CODELKUP CL1 (NOLOCK) ON CL1.STORERKEY = PH.STORERKEY AND CL1.LISTNAME = ''BRToll'' AND CL1.Code = ORD.Shipperkey ' + CHAR(13)
                  +  ' LEFT JOIN CODELKUP CL2 (NOLOCK) ON CL2.STORERKEY = PH.STORERKEY AND CL2.LISTNAME = ''TollCity'' AND CL2.CODE = ORD.C_Zip ' + CHAR(13)
                  +  '                                AND CL2.UDF01 = ORD.M_Country '+ CHAR(13)   --WL02
               --   +  ' LEFT JOIN CODELKUP CL3 (NOLOCK) ON CL3.STORERKEY = PH.STORERKEY AND CL3.LISTNAME = ''BRCNFAC'' AND CL3.CODE = ORD.Facility ' + CHAR(13)
                  +  ' WHERE ORD.loadkey = @c_Sparm01 '             + CHAR(13)
                  +  ' AND ORD.Orderkey = @c_Sparm02 '              + CHAR(13)
                  +  ' AND PD.Cartonno >= CONVERT(INT,@c_Sparm05) ' + CHAR(13)                             
                  +  ' AND PD.Cartonno <= CONVERT(INT,@c_Sparm06) '
         
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
  
  
   SET @c_ExecArguments = N'   @c_Sparm01          NVARCHAR(80) '      
                         + ',  @c_Sparm02          NVARCHAR(80) '      
                         + ',  @c_Sparm03          NVARCHAR(80) ' 
                         + ',  @c_Sparm04          NVARCHAR(80) ' 
                         + ',  @c_Sparm05          NVARCHAR(80) ' 
                         + ',  @c_Sparm06          NVARCHAR(80) ' 
                                              
   EXEC sp_ExecuteSql     @c_SQL       
                        , @c_ExecArguments      
                        , @c_Sparm01     
                        , @c_Sparm02  
                        , @c_Sparm03
                        , @c_Sparm04
                        , @c_Sparm05
                        , @c_Sparm06
                               
    --EXEC sp_executesql @c_SQL  
    
   --SELECT @n_Sum = SUM(SKU.STDNETWGT * PD.Qty)
   --FROM PACKDETAIL PD (NOLOCK) 
   --JOIN SKU (NOLOCK) ON PD.SKU = SKU.SKU AND SKU.STORERKEY = PD.STORERKEY
   --WHERE PD.LABELNO = @c_Sparm01

   SELECT @n_Sum = CAST(PIF.[Weight] AS DECIMAL(10, 1)) --ROUND(PIF.[Weight],1)
   FROM PACKINFO PIF (NOLOCK)
   JOIN #Result R (NOLOCK) ON R.Col57 = PIF.Pickslipno
   WHERE PIF.Cartonno >= CONVERT(INT,@c_Sparm05) AND PIF.Cartonno <= CONVERT(INT,@c_Sparm06) 

   --SELECT @n_Sum 

   UPDATE #Result
   SET COL27 = SUBSTRING(COL27,1,47) + RIGHT('000000' + REPLACE(CAST(@n_Sum AS NVARCHAR(6)),'.',''), 6) + SPACE(2) + 'NNN' + SPACE(3)
   --WHERE COL59 = @c_Sparm01
 
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
      @c_TraceName = 'isp_BT_Bartender_CN_Shipper_TollLabel_BoardRiders',    
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
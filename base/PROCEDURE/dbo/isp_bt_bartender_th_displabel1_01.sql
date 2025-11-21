SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
  
/******************************************************************************/                   
/* Copyright: IDS                                                             */                   
/* Purpose: isp_BT_Bartender_TH_DISPLABEL1_01                                 */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */                   
/* 2021-02-25 1.0  CSCHONG    Created (WMS-16406)                             */   
/* 2021-11-11 1.1  CSCHONG    Devops Scripts combine                          */     
/* 2021-11-11 1.1  CSCHONG    WMS-16406 revised noofcopy rule (CS01)          */         
/******************************************************************************/                  
CREATE PROC [dbo].[isp_BT_Bartender_TH_DISPLABEL1_01]                        
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
      @n_sequence        INT,   
      @n_TTLPage         INT,
      @n_NoofCopy        INT                    --CS01       
            
      
  DECLARE @d_Trace_StartTime   DATETIME,     
           @d_Trace_EndTime    DATETIME,    
           @c_Trace_ModuleName NVARCHAR(20),     
           @d_Trace_Step1      DATETIME,     
           @c_Trace_Step1      NVARCHAR(20),    
           @c_UserName         NVARCHAR(20),  
           @c_condition        NVARCHAR(150) ,  
           @c_SQLGroup         NVARCHAR(4000),   
           @c_ExecArguments    NVARCHAR(4000) 
    
   SET @d_Trace_StartTime = GETDATE()    
   SET @c_Trace_ModuleName = ''    
          
    -- SET RowNo = 0               
   

    SET @n_sequence  = 1    
    SET @n_TTLPage = CAST( @c_Sparm02 AS INT)   
    SET @c_condition= ''  
    SET @c_SQLGroup = ''
    SET @n_NoofCopy = CAST(@c_Sparm02 AS INT)  --CS01
                
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
        
   
  WHILE @n_NoofCopy >= 1   --CS01 START
  BEGIN
          
   SET @c_ExecArguments = ''                       

  
       
     SET @c_SQLJOIN = +N' SELECT ''Dispatch Label'',MD.mbolkey,LTRIM(OH.C_Company),'
             + ' (ISNULL(LTRIM(OH.C_address3),'''') + ISNULL(LTRIM(OH.C_address2),'''')),ISNULL(LTRIM(OH.C_address1),''''),'       --5  
             + ' ISNULL(LTRIM(OH.C_city),''''),ISNULL(LTRIM(OH.C_Zip),''''),OH.[Route],OH.ExternOrderKey,'
             + ' CONVERT(NVARCHAR(10), OH.DeliveryDate, 103),' --10                  
             + ' OH.ExternOrderKey,CAST(@n_sequence as NVARCHAR(5)) + ''of'' + @c_Sparm02,ISNULL(LTRIM(OH.B_contact1),''''),'
             + ' ISNULL(LTRIM(OH.B_Address1),''''),ISNULL(LTRIM(OH.B_Address2),''''),'     --15     
             + ' ISNULL(LTRIM(OH.B_Address3),''''),ISNULL(LTRIM(OH.B_Address4),''''),ISNULL(LTRIM(OH.C_contact1),''''),OH.PmtTerm,'     --19         
         --    + CHAR(13) +        
             + ' SUBSTRING(ISNULL(OH.notes,''''),1,80),OH.C_ISOCntryCode,OH.C_phone1,OH.C_Country,OH.dischargeplace,OH.deliveryplace,'
             + ' OH.M_company,OH.M_Address1,OH.Shipperkey,OH.consigneekey,OH.Orderkey,'  --30    
             + ' '''','''','''','''','''','''','''','''','''','''','   --40         
             + ' '''','''','''','''','''','''','''','''','''','''', '  --50         
             + ' '''','''','''','''','''','''','''','''','''','''' '   --60            
           --  + CHAR(13) +              
             + ' FROM ORDERS OH WITH (NOLOCK)  ' + CHAR(13) +  
             + ' LEFT JOIN MBOLDETAIL MD WITH (NOLOCK) ON (MD.orderkey = OH.Orderkey)'   
             + '  WHERE OH.Orderkey = @c_Sparm01 '  
             + ' GROUP BY MD.mbolkey,LTRIM(OH.C_Company),(ISNULL(LTRIM(OH.C_address3),'''') + ISNULL(LTRIM(OH.C_address2),'''')),ISNULL(LTRIM(OH.C_address1),''''), '  
             + ' ISNULL(LTRIM(OH.C_city),''''),ISNULL(LTRIM(OH.C_Zip),''''),OH.[Route],OH.ExternOrderKey, CONVERT(NVARCHAR(10), OH.DeliveryDate, 103),'  
             + ' ISNULL(LTRIM(OH.B_contact1),''''),ISNULL(LTRIM(OH.B_Address1),''''),ISNULL(LTRIM(OH.B_Address2),''''),ISNULL(LTRIM(OH.B_Address3),''''),'
             + ' ISNULL(LTRIM(OH.B_Address4),''''),ISNULL(LTRIM(OH.C_contact1),''''),OH.PmtTerm,SUBSTRING(ISNULL(OH.notes,''''),1,80),OH.C_ISOCntryCode,'
             + ' OH.C_phone1,OH.C_Country,OH.dischargeplace,OH.deliveryplace,OH.M_company,OH.M_Address1,OH.Shipperkey,OH.consigneekey,OH.Orderkey'
            
  IF @b_debug=1          
  BEGIN          
   SELECT @c_SQLJOIN            
  END                  
                
  SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +             
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +             
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +             
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +             
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +             
             + ',Col55,Col56,Col57,Col58,Col59,Col60) '            
      
    SET @c_SQL = @c_SQL + @c_SQLJOIN    
  
    SET @c_ExecArguments = N'@c_Sparm01  NVARCHAR(280)'  
                       +',@c_Sparm02  NVARCHAR(280)'  
                       +',@n_sequence INT'   
                                    
  
            EXEC sp_ExecuteSql @c_SQL   
                             , @c_ExecArguments  
                             , @c_Sparm01  
                             , @c_Sparm02
                             , @n_sequence  


    SET @n_NoofCopy = @n_NoofCopy - 1
    SET @n_sequence = @n_sequence + 1
              
 END   --CS01 END         
--EXEC sp_executesql @c_SQL            
          
   IF @b_debug=1          
   BEGIN            
      PRINT @c_SQL            
   END          
   IF @b_debug=1          
   BEGIN          
      SELECT * FROM #Result (nolock)             END                    
         
              
   EXIT_SP:      
    
   SET @d_Trace_EndTime = GETDATE()    
   SET @c_UserName = SUSER_SNAME()                 
     
   SELECT * FROM #Result (nolock)   
                                    
END -- procedure     

GO
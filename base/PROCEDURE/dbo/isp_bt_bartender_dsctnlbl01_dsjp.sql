SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Copyright: LFL                                                             */
/* Purpose: isp_BT_Bartender_DSCTNLBL01_DSJP                                  */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2020-06-16 1.0  WLChooi    Created (WMS-13664)                             */
/* 2020-07-03 1.1  WLChooi    WMS-14124 - Remove SKU and LabelLine, change to */
/*                            SUM(Unitprice) (WL01)                           */
/* 2021-04-02 1.2  CSCHONG    WMS-16024 PB-Standardize TrackingN (CS01)       */ 
/* 2021-05-20 1.3  WLChooi    Merge and Sync with PROD version (WL02)         */
/******************************************************************************/

CREATE PROC [dbo].[isp_BT_Bartender_DSCTNLBL01_DSJP]
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
                                
   DECLARE @c_SQL              NVARCHAR(4000),          
           @c_SQLSORT          NVARCHAR(4000),          
           @c_SQLJOIN          NVARCHAR(4000)

   DECLARE @d_Trace_StartTime  DATETIME,     
           @d_Trace_EndTime    DATETIME,    
           @c_Trace_ModuleName NVARCHAR(20),     
           @d_Trace_Step1      DATETIME,     
           @c_Trace_Step1      NVARCHAR(20),    
           @c_UserName         NVARCHAR(20),                       
           @c_ExecStatements   NVARCHAR(4000),      
           @c_ExecArguments    NVARCHAR(4000)
    
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
                  
   SET @c_SQLJOIN = '  SELECT DISTINCT ORD.Orderkey, ORD.ExternOrderKey, ORD.Consigneekey, ORD.C_contact1, ORD.C_contact2 ' + CHAR(13)   --5   --WL01
                  + ', ORD.C_company, ISNULL(ORD.C_address1,''''), ISNULL(ORD.C_address2,'''') ' + CHAR(13)   --8
                  + ', ISNULL(ORD.C_address3,''''), ISNULL(ORD.C_address4,'''') ' + CHAR(13)   --10
                  +N', ORD.C_city, ORD.C_State, N''〒'' + Substring(ORD.C_Zip,1,3) + ''-'' + Substring(ORD.C_Zip,4,4) ' + CHAR(13)   --13
                  + ', ISNULL(ORD.C_Phone1,''''), ISNULL(ORD.C_Phone2,''''), ISNULL(ORD.BuyerPO,'''') ' + CHAR(13)   --16
                  + ', ISNULL(ORD.B_Contact1,''''), ISNULL(ORD.B_Contact2,''''), ISNULL(ORD.B_Company,'''') ' + CHAR(13)   --19
                  + ', ISNULL(ORD.B_Address1,''''), ISNULL(ORD.B_Address2,''''), ISNULL(ORD.B_Address3,'''') ' + CHAR(13)   --22
                  + ', ISNULL(ORD.B_Address4,''''), ISNULL(ORD.B_City,''''), ISNULL(ORD.B_State,'''') ' + CHAR(13)   --25
                  + ', ISNULL(ORD.B_Zip,''''), ISNULL(ORD.B_Phone1,''''), ISNULL(ORD.B_Phone2,'''') ' + CHAR(13)   --28
                  + ', ISNULL(ORD.DischargePlace,''''), ORD.Loadkey, ORD.Mbolkey, ISNULL(ORD.trackingno,'''') ' + CHAR(13)   --32    --CS01
                  + ', ORD.TrackingNo, CONVERT(NVARCHAR(80), ORD.InvoiceAmount), '''', CAST(SUM(ISNULL(ORDTL.UnitPrice,0)) AS NVARCHAR(80)), PAH.PickSlipNo ' + CHAR(13)   --37   --WL01
                  + ', ORD.UserDefine09, PAH.TTLCNTS, PAH.CtnTyp1, PAH.CtnTyp2, PAD.CartonNo ' + CHAR(13)   --42
                  + ', PAD.LabelNo, '''', PAD.DropID ' + CHAR(13)   --45   --WL01
                  + ', (SELECT SUM(PD.Qty) FROM PACKDETAIL PD (NOLOCK) WHERE PD.PickSlipNo = PAH.PickSlipNo AND PD.CartonNo = PAD.CartonNo) ' + CHAR(13)   --46   --WL01
                  + ', ISNULL(PIF.UCCNo,''''), PIF.CartonType, ISNULL(ST.Company,''''), ISNULL(ST.Address1,'''') ' + CHAR(13)   --50
                  + ', ISNULL(ST.Address2,''''), ISNULL(ST.City,''''), ISNULL(ST.State,'''') ' + CHAR(13)   --53
                  + ', ISNULL(ST.Zip,''''), ISNULL(ST.Phone1,''''), ISNULL(ST.B_Company,'''') ' + CHAR(13)   --56
                  + ', ISNULL(ST.B_Phone1,''''), ISNULL(ST.Notes2,'''') ' + CHAR(13)   --58
                  + ', ISNULL(CL.UDF01,''''), ISNULL(CL.UDF02,'''') ' + CHAR(13)   --60
                  + 'FROM ORDERS ORD (NOLOCK) ' + CHAR(13)
                  + 'JOIN ORDERDETAIL ORDTL (NOLOCK) ON ORDTL.Orderkey = ORD.OrderKey ' + CHAR(13)
                  + 'JOIN PACKHEADER PAH (NOLOCK) ON PAH.Orderkey = ORD.Orderkey ' + CHAR(13)
                  + 'JOIN PACKDETAIL PAD (NOLOCK) ON PAD.Pickslipno = PAH.Pickslipno AND PAD.SKU = ORDTL.SKU AND PAD.StorerKey = ORDTL.StorerKey ' + CHAR(13)
                  + 'JOIN PACKINFO PIF (NOLOCK) ON PIF.PickSlipNo = PAD.PickSlipNo AND PIF.CartonNo = PAD.CartonNo ' + CHAR(13)
                  + 'JOIN STORER ST (NOLOCK) ON ST.StorerKey = ORD.StorerKey ' + CHAR(13)
                  + 'LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = ''DSGLBL'' AND CL.Storerkey = ORD.StorerKey AND CL.Code = ''A1'' ' + CHAR(13)
                  + 'WHERE PAH.Pickslipno = @c_Sparm01 ' + CHAR(13)
                  + 'AND PAD.CartonNo = CASE WHEN ISNULL(@c_Sparm02,'''') = '''' THEN PAD.CartonNo ELSE @c_Sparm02 END '
                  --WL01 START
                  + '  GROUP BY ORD.Orderkey, ORD.ExternOrderKey, ORD.Consigneekey, ORD.C_contact1, ORD.C_contact2 ' + CHAR(13)  
                  + ', ORD.C_company, ISNULL(ORD.C_address1,''''), ISNULL(ORD.C_address2,'''') ' + CHAR(13)  
                  + ', ISNULL(ORD.C_address3,''''), ISNULL(ORD.C_address4,'''') ' + CHAR(13)  
                  +N', ORD.C_city, ORD.C_State, N''〒'' + Substring(ORD.C_Zip,1,3) + ''-'' + Substring(ORD.C_Zip,4,4) ' + CHAR(13)   
                  + ', ISNULL(ORD.C_Phone1,''''), ISNULL(ORD.C_Phone2,''''), ISNULL(ORD.BuyerPO,'''') ' + CHAR(13)  
                  + ', ISNULL(ORD.B_Contact1,''''), ISNULL(ORD.B_Contact2,''''), ISNULL(ORD.B_Company,'''') ' + CHAR(13)   
                  + ', ISNULL(ORD.B_Address1,''''), ISNULL(ORD.B_Address2,''''), ISNULL(ORD.B_Address3,'''') ' + CHAR(13) 
                  + ', ISNULL(ORD.B_Address4,''''), ISNULL(ORD.B_City,''''), ISNULL(ORD.B_State,'''') ' + CHAR(13)   
                  + ', ISNULL(ORD.B_Zip,''''), ISNULL(ORD.B_Phone1,''''), ISNULL(ORD.B_Phone2,'''') ' + CHAR(13)  
                  + ', ISNULL(ORD.DischargePlace,''''), ORD.Loadkey, ORD.Mbolkey, ISNULL(ORD.trackingno,'''') ' + CHAR(13)   --WL02  
                  + ', ORD.TrackingNo, CONVERT(NVARCHAR(80), ORD.InvoiceAmount), PAH.PickSlipNo ' + CHAR(13)  
                  + ', ORD.UserDefine09, PAH.TTLCNTS, PAH.CtnTyp1, PAH.CtnTyp2, PAD.CartonNo ' + CHAR(13)   
                  + ', PAD.LabelNo, PAD.DropID ' + CHAR(13) 
                  + ', ISNULL(PIF.UCCNo,''''), PIF.CartonType, ISNULL(ST.Company,''''), ISNULL(ST.Address1,'''') ' + CHAR(13) 
                  + ', ISNULL(ST.Address2,''''), ISNULL(ST.City,''''), ISNULL(ST.State,'''') ' + CHAR(13)   
                  + ', ISNULL(ST.Zip,''''), ISNULL(ST.Phone1,''''), ISNULL(ST.B_Company,'''') ' + CHAR(13)  
                  + ', ISNULL(ST.B_Phone1,''''), ISNULL(ST.Notes2,'''') ' + CHAR(13)   
                  + ', ISNULL(CL.UDF01,''''), ISNULL(CL.UDF02,'''') ' + CHAR(13) 
                  --WL01 END
 
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
  
  
   SET @c_ExecArguments = N'  @c_Sparm01          NVARCHAR(80)'      
                         + ', @c_Sparm02          NVARCHAR(80) '   
                         + ', @c_Sparm03          NVARCHAR(80) '       
                           
                           
   EXEC sp_ExecuteSql     @c_SQL       
                        , @c_ExecArguments      
                        , @c_Sparm01     
                        , @c_Sparm02   
                        , @c_Sparm03        
          
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
   
   IF OBJECT_ID('tempdb..#Result') IS NOT NULL
      DROP TABLE #Result  
                           
END -- procedure     

GO
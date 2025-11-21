SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
     
/******************************************************************************/                       
/* Copyright: IDS                                                             */                       
/* Purpose:   isp_BT_UCCLBL_TH_UA                                             */                       
/*                                                                            */                       
/* Modifications log:                                                         */                       
/*                                                                            */                       
/* Date       Rev  Author     Purposes                                        */    
/*02-Apr-2020 1.0  CSCHONG   WMS-12603 TH-UA_Ecom_Shipping label              */  
/*28-Apr-2020 1.1  CSCHONG   WMS-12603 add table link logic (CS01)            */
/*12-Mar-2021 1.2  WLChooi   WMS-16549 - New Data Source for KerryTH (WL01)   */
/*05-May-2021 1.3  WLChooi   WMS-16549 - Bug Fix (WL01)                       */
/*13-Jan-2022 1.4  Mingle    WMS-18725 - Remove '-' in extordkey (ML01)       */
/*13-Jan-2022 1.5  Mingle    DevOps Combine Script                            */
/******************************************************************************/                      
                        
CREATE PROC [dbo].[isp_BT_UCCLBL_TH_UA]                            
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
      @c_OrderKey        NVARCHAR(10),                          
      @c_ExternOrderKey  NVARCHAR(10),                    
      @c_Deliverydate    DATETIME,                    
      @n_intFlag         INT,           
      @n_CntRec          INT,          
      @c_SQL             NVARCHAR(4000),              
      @c_SQLSORT         NVARCHAR(4000),              
      @c_SQLJOIN         NVARCHAR(4000),      
      @c_RecType         NVARCHAR(20),            
      @c_storerkey       NVARCHAR(20),             
      @c_ExecStatements  NVARCHAR(4000),            
      @c_ExecArguments   NVARCHAR(4000)              
          
  DECLARE  @d_Trace_StartTime  DATETIME,         
           @d_Trace_EndTime    DATETIME,        
           @c_Trace_ModuleName NVARCHAR(20),         
           @d_Trace_Step1      DATETIME,         
           @c_Trace_Step1      NVARCHAR(20),        
           @c_UserName         NVARCHAR(20),    
           @c_Shipperkey       NVARCHAR(15),   --WL01
         
           @n_Qty INT,    
           @n_Weight FLOAT,    
           @n_Price FLOAT         
        
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
      
   SELECT @n_Qty = SUM(PD.QTY)    
   FROM PACKDETAIL PD (NOLOCK)    
   WHERE PD.PICKSLIPNO = @c_Sparm01 AND PD.LABELNO = @c_Sparm02    
     
   SELECT @n_Weight = SUM([PI].Weight)    
   FROM PACKINFO [PI] (NOLOCK)    
   WHERE [PI].PICKSLIPNO = @c_Sparm01     
   AND [PI].CartonNo = (SELECT TOP 1 CARTONNO FROM PACKDETAIL (NOLOCK) WHERE PICKSLIPNO = @c_Sparm01 AND LABELNO = @c_Sparm02)    
     
   SELECT @n_Price      = SUM(ORDET.ExtendedPrice)   
        , @c_Shipperkey = MAX(ORD.ShipperKey)   --WL01
   FROM ORDERS ORD(NOLOCK)    
   JOIN ORDERDETAIL ORDET WITH (NOLOCK) ON ORD.Orderkey = ORDET.Orderkey    
   JOIN PACKHEADER PH WITH (NOLOCK) ON PH.OrderKey = ORD.OrderKey    
   WHERE PH.PICKSLIPNO = @c_Sparm01    

   SET @c_SQLJOIN = +' SELECT DISTINCT PD.LabelNo'+ CHAR(13)     
                    + ',ORD.ExternOrderkey,ORD.B_Contact1, '+ CHAR(13)     
                    + ' RTRIM(ORD.B_Address1), RTRIM(ORD.B_Address2),'+ CHAR(13)      --5    
                    + ' RTRIM(ORD.B_Address3),RTRIM(ORD.B_Address4),ORD.C_contact1,RTRIM(ORD.C_Address1),RTRIM(ORD.C_Address2), '+ CHAR(13)     --10 
                    + ' RTRIM(ORD.C_Address3),ORD.C_State + ''  '' + ORD.C_Zip,ORD.C_City, '+ CHAR(13)      
                    + ' '''',CASE WHEN ORD.SHIPPERKEY IN (''JANIO'',''GDEX'') THEN '+ CHAR(13)      
                    + ' (CASE WHEN ORD.PmtTerm = ''COD'' THEN ''COD'' ELSE '''' END) ' + CHAR(13)       --15     
                    + ' ELSE ORD.PmtTerm END,'   + CHAR(13)    
                    + ' ''DDP'',ORD.UserDefine05,'''', '+ CHAR(13)      
                    + ' CASE WHEN RTRIM(ORD.PmtTerm) = ''COD'' THEN ''COD - please collect'' ELSE ORD.PmtTerm END, '+ CHAR(13)      
                    + ' CASE WHEN PD.CartonNo = ''1'' THEN '    
                    + '(CASE WHEN RTRIM(ORD.PmtTerm) = ''Prepaid'' THEN '''' ELSE ISNULL(ORDET.UserDefine05,'''') + '' '' + CAST(@n_Price AS NVARCHAR) END) '    
                    + ' ELSE ''0'' END,'  + CHAR(13)     --20    
                    + ' '''',ORD.Notes,Ord.C_ISOCntryCode,Ord.C_Phone1,Ord.C_Country,CONVERT(NVARCHAR(80),PD.EDITDATE,103), ' + CHAR(13)   
                    + ' CT.CARTONDESCRIPTION,''8111020'',Ord.C_City,Ord.C_State,' + CHAR(13)    --30        
                    + ' Ord.C_Zip,Ord.userdefine04,ord.dischargeplace,Ord.deliveryplace,RTRIM(ORD.M_Company),RTRIM(ORD.M_address1),'''','''','''','''','  + CHAR(13) --40  --(WL02) --(CS01) --(CS02)
                    + ' '''','''','''','''','''','''','''','''','''','''', '+ CHAR(13)     --50    
                    + ' '''','''','''','''','''','''','''','''',PH.Pickslipno,''SG'' '     --60    
                    + CHAR(13)    
                    +' FROM ORDERS ORD WITH (NOLOCK) '  + CHAR(13)        
                    +' JOIN ORDERDETAIL ORDET WITH (NOLOCK) ON ORD.Orderkey = ORDET.Orderkey'+ CHAR(13)    
                    +' JOIN PACKHEADER PH WITH (NOLOCK) ON PH.OrderKey = ORD.OrderKey'  + CHAR(13)    
                    +' JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno AND PD.sku = ORDET.sku' + CHAR(13)     
                    +' JOIN PACKINFO PI WITH (NOLOCK) ON PD.Pickslipno = PI.Pickslipno AND PI.CartonNo = PD.CartonNo' + CHAR(13)    
                    +' JOIN STORER ST WITH (NOLOCK) ON ST.Storerkey = ORD.Storerkey '
                    +' JOIN CARTONIZATION CT WITH (NOLOCK) ON CT.CartonizationGroup = ST.Cartongroup ' + CHAR(13)     --CS01
                    + '                                    AND CT.Cartontype = PI.CartonType '                        --CS01
                    +' WHERE PD.Pickslipno =  @c_Sparm01'                                                  
                    +' AND PD.LabelNo = @c_Sparm02 '                  
                    +' GROUP BY PD.LabelNo, ' + CHAR(13)      
                    +' ORD.ExternOrderkey,ORD.B_Contact1, '+ CHAR(13)       
                    +' RTRIM(ORD.B_Address1), RTRIM(ORD.B_Address2),'     + CHAR(13)    
                    +' RTRIM(ORD.B_Address3),RTRIM(ORD.B_Address4),ORD.C_contact1,RTRIM(ORD.C_Address1),RTRIM(ORD.C_Address2), ' + CHAR(13)    
                    +' RTRIM(ORD.C_Address3),ORD.C_State,ORD.C_Zip,ORD.C_City, '+ CHAR(13)       
                    +' ORD.Shipperkey, ORD.PmtTerm, '   + CHAR(13)    
                    +' ORD.UserDefine05, '+ CHAR(13)       
                    +' PD.CartonNo, '+ CHAR(13)    
                    +' ORDET.ExtendedPrice,'   + CHAR(13)   
                    +' ORDET.UserDefine05,'    + CHAR(13)    
                    +' ORD.Notes,Ord.C_ISOCntryCode,Ord.C_Phone1,Ord.C_Country, ' + CHAR(13)  
                    +' CONVERT(NVARCHAR(80),PD.EDITDATE,103),CT.CARTONDESCRIPTION,Ord.C_City,Ord.C_State,Ord.C_Zip,' + CHAR(13) --(WL02)  
                    +' Ord.userdefine04,ord.dischargeplace,Ord.deliveryplace,PH.Pickslipno,RTRIM(ORD.M_Company),RTRIM(ORD.M_address1) '       --(CS01)  --(CS02)
                                           
   --WL01 S
   IF @c_Shipperkey = 'KerryTH'
   BEGIN
      SET @c_SQLJOIN =   ' SELECT DISTINCT LTRIM(RTRIM(ISNULL(CL.Prefix,''''))) + LTRIM(RTRIM(REPLACE(ORD.ExternOrderkey,''-'',''''))) + ' + CHAR(13) --ML01
                       + '                 RIGHT(''00000'' + CAST(PD.CartonNo AS NVARCHAR(10)), CL.CtnNoDigit),'+ CHAR(13)     
                       + ' ORD.ExternOrderkey,ORD.B_Contact1, '+ CHAR(13)     
                       + ' RTRIM(ORD.B_Address1), RTRIM(ORD.B_Address2),'+ CHAR(13)      --5    
                       + ' RTRIM(ORD.B_Address3),RTRIM(ORD.B_Address4),ORD.C_contact1,RTRIM(ORD.C_Address1),RTRIM(ORD.C_Address2), '+ CHAR(13)     --10  
                       + ' RTRIM(ORD.C_Address3),ORD.C_State + ''  '' + ORD.C_Zip,ORD.C_City, '+ CHAR(13)      
                       + ' PD.DropID,CASE WHEN ORD.SHIPPERKEY IN (''JANIO'',''GDEX'') THEN '+ CHAR(13)      
                       + ' (CASE WHEN ORD.PmtTerm = ''COD'' THEN ''COD'' ELSE '''' END) ' + CHAR(13)       --15     
                       + ' ELSE ORD.PmtTerm END,'   + CHAR(13)    
                       + ' ISNULL(CL.UDF01,''''),ORD.UserDefine05,'''', '+ CHAR(13)      
                       + ' CASE WHEN RTRIM(ORD.PmtTerm) = ''COD'' THEN ''COD - please collect'' ELSE ORD.PmtTerm END, '+ CHAR(13)      
                       + ' CASE WHEN PD.CartonNo = ''1'' THEN '    
                       + '(CASE WHEN RTRIM(ORD.PmtTerm) = ''Prepaid'' THEN '''' ELSE ISNULL(ORDET.UserDefine05,'''') + '' '' + CAST(@n_Price AS NVARCHAR) END) '    
                       + ' ELSE ''0'' END,'  + CHAR(13)     --20    
                       + ' '''',ORD.Notes,Ord.C_ISOCntryCode,Ord.C_Phone1,Ord.C_Country,CONVERT(NVARCHAR(80),PD.EDITDATE,103), ' + CHAR(13)   
                       + ' CT.CARTONDESCRIPTION,ISNULL(CL.UDF02,''''),Ord.C_City,Ord.C_State,' + CHAR(13)    --30        
                       + ' Ord.C_Zip,Ord.userdefine04,ord.dischargeplace,Ord.deliveryplace,RTRIM(ORD.M_Company),RTRIM(ORD.M_address1), ' + CHAR(13)   --36
                       + ' ORD.Shipperkey,ORD.Consigneekey,ORD.PmtTerm,PD.DropID,'  + CHAR(13) --40 
                       + ' '''','''','''','''','''','''','''','''','''','''', '+ CHAR(13)     --50    
                       + ' '''','''','''','''','''','''','''','''',PH.Pickslipno,''TH'' '     --60    
                       + CHAR(13)    
                       +' FROM ORDERS ORD WITH (NOLOCK) '  + CHAR(13)        
                       +' JOIN ORDERDETAIL ORDET WITH (NOLOCK) ON ORD.Orderkey = ORDET.Orderkey'+ CHAR(13)    
                       +' JOIN PACKHEADER PH WITH (NOLOCK) ON PH.OrderKey = ORD.OrderKey'  + CHAR(13)    
                       +' JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno AND PD.sku = ORDET.sku' + CHAR(13)     
                       +' LEFT JOIN PACKINFO PI WITH (NOLOCK) ON PD.Pickslipno = PI.Pickslipno AND PI.CartonNo = PD.CartonNo' + CHAR(13)    
                       +' JOIN STORER ST WITH (NOLOCK) ON ST.Storerkey = ORD.Storerkey '
                       +' LEFT JOIN CARTONIZATION CT WITH (NOLOCK) ON CT.CartonizationGroup = ST.Cartongroup ' + CHAR(13) 
                       + '                                    AND CT.Cartontype = PI.CartonType ' + CHAR(13)
                       + 'CROSS APPLY (SELECT MAX(Code) AS Prefix, MAX(Short) AS CtnNoDigit, MAX(UDF01) AS UDF01, MAX(UDF02) AS UDF02' + CHAR(13)
                       + '             FROM CODELKUP (NOLOCK) WHERE Listname = ''UACOMPREFI'' AND Long = ORD.Shipperkey) AS CL' + CHAR(13)
                       +' WHERE PD.Pickslipno =  @c_Sparm01'                                                  
                       +' AND PD.LabelNo = @c_Sparm02 '                  
                       +' GROUP BY PD.LabelNo, ' + CHAR(13)      
                       +' ORD.ExternOrderkey,ORD.B_Contact1, '+ CHAR(13)       
                       +' RTRIM(ORD.B_Address1), RTRIM(ORD.B_Address2),'     + CHAR(13)    
                       +' RTRIM(ORD.B_Address3),RTRIM(ORD.B_Address4),ORD.C_contact1,RTRIM(ORD.C_Address1),RTRIM(ORD.C_Address2), ' + CHAR(13)    
                       +' RTRIM(ORD.C_Address3),ORD.C_State,ORD.C_Zip,ORD.C_City, '+ CHAR(13)       
                       +' ORD.Shipperkey, ORD.PmtTerm, '   + CHAR(13)    
                       +' ORD.UserDefine05, '+ CHAR(13)       
                       +' PD.CartonNo, '+ CHAR(13)    
                       +' ORDET.ExtendedPrice,'   + CHAR(13)   
                       +' ORDET.UserDefine05,'    + CHAR(13)    
                       +' ORD.Notes,Ord.C_ISOCntryCode,Ord.C_Phone1,Ord.C_Country, ' + CHAR(13)  
                       +' CONVERT(NVARCHAR(80),PD.EDITDATE,103),CT.CARTONDESCRIPTION,Ord.C_City,Ord.C_State,Ord.C_Zip,' + CHAR(13)
                       +' Ord.userdefine04,ord.dischargeplace,Ord.deliveryplace,PH.Pickslipno,RTRIM(ORD.M_Company),RTRIM(ORD.M_address1), ' + CHAR(13)
                       +' ISNULL(CL.UDF01,''''), ISNULL(CL.UDF02,''''), ORD.Consigneekey, ' + CHAR(13)
                       +' LTRIM(RTRIM(ISNULL(CL.Prefix,''''))) + LTRIM(RTRIM(REPLACE(ORD.ExternOrderkey,''-'',''''))) + ' + CHAR(13)
                       +' RIGHT(''00000'' + CAST(PD.CartonNo AS NVARCHAR(10)), CL.CtnNoDigit), PD.DropID '
   END
   --WL01 E
                
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
                 
   --EXEC sp_executesql @c_SQL        
       
   SET @c_ExecArguments = N'  @c_Sparm01         NVARCHAR(80)'        
                         + ' ,@c_Sparm02         NVARCHAR(80)'        
                         + ' ,@c_Sparm03         NVARCHAR(80)'        
                         + ' ,@c_Sparm04         NVARCHAR(80)'        
                         + ' ,@c_Sparm05         NVARCHAR(80)'     
                         + ' ,@n_Price           FLOAT '       
                               
                                             
   EXEC sp_ExecuteSql     @c_SQL           
                        , @c_ExecArguments          
                        , @c_Sparm01       
                        , @c_Sparm02           
                        , @c_Sparm03          
                        , @c_Sparm04         
                        , @c_Sparm05     
                        , @n_Price        
          
   UPDATE #Result    
   SET COL18 = @n_qty, COL21 = @n_Weight    
   WHERE COL01 = @c_sparm02    

   --WL02 S
   IF @c_Shipperkey = 'KerryTH'
   BEGIN
      UPDATE #Result    
      SET COL18 = @n_qty, COL21 = @n_Weight    
      WHERE COL59 = @c_sparm01    
   END
   --WL02 E
      
                 
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
      @c_TraceName = 'isp_BT_UCCLBL_TH_UA',        
      @c_starttime = @d_Trace_StartTime,        
      @c_endtime   = @d_Trace_EndTime,        
      @c_step1     = @c_UserName,        
      @c_step2     = '',        
      @c_step3     = '',        
      @c_step4     = '',        
      @c_step5     = '',        
      @c_col1      = @c_Sparm01,         
      @c_col2      = @c_Sparm02,        
      @c_col3      = @c_Sparm03,        
      @c_col4      = @c_Sparm04,        
      @c_col5      = @c_Sparm05,        
      @b_Success   = 1,        
      @n_Err       = 0,        
      @c_ErrMsg    = ''                    
            
           
                                           
END -- procedure  


GO
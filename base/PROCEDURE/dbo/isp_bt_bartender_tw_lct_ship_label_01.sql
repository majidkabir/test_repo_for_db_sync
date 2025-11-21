SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/                   
/* Copyright: IDS                                                             */                   
/* Purpose: isp_BT_Bartender_TW_LCT_ship_Label_01                             */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */
/* 2017-08-10 1.0  CSCHONG    Created (WMS-2413)                              */                     
/* 2018-10-3  1.0  ZCCHAN     Created (WMS-6064)                              */
/* 2018-11-26 1.1  WLCHOOI    WMS-7107 - Add 2 new fields  (WL01)             */   
/* 2020-03-16 1.2  WLChooi    WMS-12464 - Add and modify mapping (WL02)       */     
/* 2021-10-06 1.3  WLChooi    DevOps Combine Script                           */    
/* 2021-10-06 1.4  WLChooi    WMS-18099 - Add Col32 (WL03)                    */   
/* 2022-06-13 1.5  WyeChun    JSM-73697 - Adviced by WaiLum to modify the     */  
/*                            query (WC01)                                    */       
/* 2022-05-06 1.6  WLChooi    WMS-19600 - Add/modify columns (WL04)           */  
/******************************************************************************/                  
                    
CREATE PROC [dbo].[isp_BT_Bartender_TW_LCT_ship_Label_01]                        
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
      @c_Uccno           NVARCHAR(20),                      
      @c_Sku             NVARCHAR(20),                           
      @n_intFlag         INT,       
      @n_CntRec          INT,      
      @c_SQL             NVARCHAR(MAX),         --WL01  
      @c_SQLSORT         NVARCHAR(MAX),         --WL01            
      @c_SQLJOIN         NVARCHAR(MAX),         --WL01   
      @c_SQLJOIN2        NVARCHAR(MAX),         --WL02
      @n_totalcase       INT,  
      @n_sequence        INT,  
      @c_skugroup        NVARCHAR(10),  
      @n_CntSku          INT,  
      @n_TTLQty          INT,  
      @c_Pickslipno      NVARCHAR(20),  
      @c_Orderkey        NVARCHAR(20),  
      @c_col18           NVARCHAR(60),  
      @c_col19           NVARCHAR(60),
      @c_Col31           NVARCHAR(80),   --WL02
      @c_TrackingNo      NVARCHAR(80)    --WL02
             
            
      
   DECLARE @d_Trace_StartTime  DATETIME,     
           @d_Trace_EndTime    DATETIME,    
           @c_Trace_ModuleName NVARCHAR(20),     
           @d_Trace_Step1      DATETIME,     
           @c_Trace_Step1      NVARCHAR(20),    
           @c_UserName         NVARCHAR(20)     
             
   DECLARE @c_ExecStatements       NVARCHAR(MAX)    
         , @c_ExecArguments        NVARCHAR(MAX)    
         , @c_ExecStatements2      NVARCHAR(MAX)    
         , @c_ExecStatementsAll    NVARCHAR(MAX)      
         , @n_continue             INT               
    
   SET @d_Trace_StartTime = GETDATE()    
   SET @c_Trace_ModuleName = ''    
          
    -- SET RowNo = 0               
   SET @c_SQL = ''    
   SET @c_Sku = ''   
   SET @c_skugroup = ''      
   SET @n_totalcase = 0    
   SET @n_sequence  = 1   
   SET @n_CntSku = 1    
   SET @n_TTLQty = 0       
      
      
   --WHILE @@TRANCOUNT > 0  
   --BEGIN  
   --   COMMIT TRAN  
   --END     
      
   -- SELECT @@TRANCOUNT '@@TRANCOUNT'      
                
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
                
	
  --BEGIN TRAN            
   SET @c_SQLJOIN = +N' SELECT DISTINCT ISNULL(o.route,''''), ' --1
             + ' CASE WHEN LTRIM(RTRIM(ISNULL(o.TrackingNo,''''))) = '''' THEN ISNULL(CT.TrackingNo,'''') ELSE ISNULL(o.trackingno,'''') END, ' --2 --WL02
             + ' ISNULL(o.orderdate,''''), ISNULL(o.deliverydate,''''),'       --4  
             + ' CASE WHEN ISNULL(C.Description,'''') <> '''' THEN ISNULL(C.Description,'''') ELSE ISNULL(C4.Description,'''') END,' --5 --CS01  
             + ' ISNULL(C1.short,''''),'  --6
             + ' ISNULL(rtrim(o.C_Address1),'''')+ISNULL(rtrim(o.C_Address2),'''')+ISNULL(rtrim(o.C_Address3),'''')+ISNULL(rtrim(o.C_Address4),''''),'  --7  
             + ' ISNULL(o.c_company,''''), '--ISNULL(rtrim(F.Address1),'''')+ISNULL(rtrim(F.Address2),'''')+ISNULL(rtrim(F.Address3),'''')+ISNULL(rtrim(F.Address4),''''),'  --9  
             + ' ISNULL(C5.Notes,''''), ' --9 --WL02
             + ' CASE WHEN LEN(C2.udf01) > 0 THEN ISNULL(c2.udf01,'''') ELSE ISNULL(C5.Long,'''') END, CASE WHEN LEN(C2.long) > 0 THEN ISNULL(c2.long,'''') ELSE ISNULL(C5.UDF03,'''') END,'--11  --WL02
             + ' isnull(rtrim(o.notes),'''')+isnull(rtrim(o.notes2),''''),' --12        
             + ' ISNULL(o.externorderkey,''''), ISNULL(C1.long,''''),'   --14
             + N' CASE WHEN ISNULL(ORDIF.orderinfo03,'''') = ''COD'' THEN ISNULL(CAST(ORDIF.payableamount AS NVARCHAR(30)),0)  ELSE N''不收款'' END, ' --15      
             + ' ISNULL(o.c_zip,''''),ISNULL(C3.long,''60CM''),'''','''',ISNULL(ORDIF.Orderinfo05,''''),'     --20                      
         --    + CHAR(13) +        
             + ' ISNULL(o.c_phone1,''''),ISNULL(o.c_phone2,''''),ISNULL(o.C_Contact1,''''),ISNULL(o.OrderKey,''''),ORDIF.orderinfo04, PD.CartonNo, '  --26  --WL01
             + ' ISNULL(CT.TrackingNo,''''), '  --27 --WL01
             + ' LTRIM(RTRIM(ISNULL(o.Route,''''))) + ''-'' + LEFT(LTRIM(RTRIM(ISNULL(o.C_Zip,''''))),3) + ''-'' + SUBSTRING(LTRIM(RTRIM(ISNULL(o.C_Zip,''''))),4,2) + ''-'' + LTRIM(RTRIM(ISNULL(o.Door,''''))), ' --28 --WL02
             + ' LTRIM(RTRIM(ISNULL(o.Externorderkey,''''))) + '' / '' + LTRIM(RTRIM(ISNULL(o.Orderkey,''''))), ' --29   --WL02
             + ' ''+'' + LTRIM(RTRIM(ISNULL(o.Route,''''))) + LTRIM(RTRIM(ISNULL(o.C_Zip,''''))),'  --30    --WL02
             + ' '''',ISNULL(C6.Long,''''),ISNULL(o.BuyerPO,''''),ISNULL(ORDIF.EcomOrderId,''''),ISNULL(C7.Description,''''), '   --WL04
             + ' ISNULL(C7.Notes,''''),ISNULL(C7.Long,''''),CONVERT(NVARCHAR(10), GETDATE(), 120),CONVERT(NVARCHAR(10), DATEADD(D, 1, GETDATE()), 120),'''','   --40   --WL03   --WL04        
             + ' '''','''','''','''','''','''','''','''','''','''', '  --50         
             + ' '''','''','''','''','''','''','''',pd.pickslipno,O.Orderkey,'''' '   --60            
           --  + CHAR(13) +              
             + ' FROM PackHeader AS ph WITH (NOLOCK)'         
             + ' JOIN PackDetail AS pd WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo'     
             + ' JOIN ORDERS AS o WITH (NOLOCK) ON o.OrderKey = ph.OrderKey '      
             + ' LEFT JOIN Storer ST WITH (NOLOCK) ON ST.storerkey=o.storerkey '               --(CS01)    
             + ' JOIN SKU S WITH (NOLOCK) ON S.storerkey = PD.Storerkey AND S.sku=PD.sku'  
             + ' LEFT JOIN CARTONTRACK CT WITH (NOLOCK) ON CT.labelno=O.orderkey AND PD.CartonNo = CASE WHEN ISNUMERIC(CT.CARRIERREF2) = 1 THEN ISNULL(NULLIF(CT.CARRIERREF2,''''),''1'') ELSE PD.CartonNo END' --WC01  
             + ' LEFT JOIN ORDERINFO ORDIF WITH (NOLOCK) ON ORDIF.orderkey=O.orderkey '       
             + ' LEFT JOIN PACKINFO PI WITH (NOLOCK) ON PI.Pickslipno = ph.pickslipno  '  
             + ' LEFT JOIN CODELKUP C   WITH (NOLOCK) ON C.listname = ''Exparvtime'' and C.Code=o.shipperkey+''_''+ORDIF.orderinfo04 and C.storerkey = O.storerkey'   
             + ' LEFT JOIN CODELKUP C1   WITH (NOLOCK) ON C1.listname = ''CarrierInf'' and C1.Code=''TCAT_ORD'' and C1.storerkey = O.storerkey'   
             + ' LEFT JOIN CODELKUP C2   WITH (NOLOCK) ON C2.listname = ''TCATLABEL'' and C2.Code=ORDIF.platform and C2.storerkey = O.storerkey'   
             + ' LEFT JOIN CODELKUP C3   WITH (NOLOCK) ON C3.listname = ''Cartontype'' and C3.Code=rtrim(pi.cartontype)+''_''+rtrim(o.shipperkey) and C3.storerkey = O.storerkey'  
             + ' LEFT JOIN CODELKUP C4   WITH (NOLOCK) ON C4.listname = ''Exparv2'' and C4.Code=o.shipperkey and C4.storerkey = O.storerkey and c4.short=''4'' '   
           --+ ' LEFT JOIN CODELKUP C5   WITH (NOLOCK) ON C5.listname = ''ECDLMODE'' and C5.Code = o.Shipperkey and C5.Storerkey = O.Storerkey 
             + ' LEFT JOIN CODELKUP C5   WITH (NOLOCK) ON C5.listname = ''COURIERADR'' and C5.Code = o.Shipperkey and C5.Storerkey = O.Storerkey and C5.Code2 = '''' '   --WL02
             + ' LEFT JOIN CODELKUP C6   WITH (NOLOCK) ON C6.listname = ''VFTCATINFO'' AND C6.Code = o.OrderGroup AND C6.Storerkey = O.Storerkey '   --WL03
             + ' LEFT JOIN CODELKUP C7   WITH (NOLOCK) ON C7.Listname = ''WebsitInfo'' AND C7.Code = ORDIF.StoreName AND C7.Storerkey = O.Storerkey '   --WL04
             + ' JOIN FACILITY F WITH (NOLOCK) ON F.facility = O.facility '  

   SET @c_SQLJOIN2 = N' WHERE pd.pickslipno = @c_Sparm01 '     
             + ' AND pd.labelno = @c_Sparm02 '      
             + ' GROUP BY ISNULL(o.route,''''), '
             + ' CASE WHEN LTRIM(RTRIM(ISNULL(o.TrackingNo,''''))) = '''' THEN ISNULL(CT.TrackingNo,'''') ELSE ISNULL(o.TrackingNo,'''') END, ' --WL02
             + ' ISNULL(o.orderdate,''''),ISNULL(o.deliverydate,''''),'       --4  
             + ' CASE WHEN ISNULL(C.Description,'''') <> '''' THEN ISNULL(C.Description,'''') ELSE ISNULL(C4.Description,'''') END,'  --CS01  
             + ' ISNULL(C1.short,''''),'  
             + ' ISNULL(rtrim(o.C_Address1),'''')+ISNULL(rtrim(o.C_Address2),'''')+ISNULL(rtrim(o.C_Address3),'''')+ISNULL(rtrim(o.C_Address4),''''),'  --7  
             + ' ISNULL(o.c_company,''''), '--ISNULL(rtrim(F.Address1),'''')+ISNULL(rtrim(F.Address2),'''')+ISNULL(rtrim(F.Address3),'''')+ISNULL(rtrim(F.Address4),''''),'   --WL02
             + ' ISNULL(C5.Notes,''''), ' --WL02 
             + ' CASE WHEN LEN(C2.udf01) > 0 THEN ISNULL(c2.udf01,'''') ELSE ISNULL(C5.Long,'''') END,CASE WHEN LEN(C2.long) > 0 THEN ISNULL(c2.long,'''') ELSE ISNULL(C5.UDF03,'''') END,'  
             + ' isnull(rtrim(o.notes),'''')+isnull(rtrim(o.notes2),''''),'     
             + ' ISNULL(o.externorderkey,''''),ISNULL(C1.long,''''),'  
             + N'CASE WHEN ISNULL(ORDIF.orderinfo03,'''') = ''COD'' THEN ISNULL(CAST(ORDIF.payableamount AS NVARCHAR(30)),0)  ELSE N''不收款'' END, '   
             + ' ISNULL(o.c_zip,''''),ISNULL(C3.long,''60CM''),ISNULL(ORDIF.Orderinfo05,''''),ISNULL(o.c_phone1,''''),ISNULL(o.c_phone2,''''),pd.pickslipno,O.Orderkey, '  
             + ' ISNULL(o.C_Contact1,''''),ISNULL(o.OrderKey,''''),ORDIF.orderinfo04,'  
             + ' PD.CartonNo,ISNULL(CT.TrackingNo,''''), '
             + ' LTRIM(RTRIM(ISNULL(o.Route,''''))) + ''-'' + LEFT(LTRIM(RTRIM(ISNULL(o.C_Zip,''''))),3) + ''-'' + SUBSTRING(LTRIM(RTRIM(ISNULL(o.C_Zip,''''))),4,2) + ''-'' + LTRIM(RTRIM(ISNULL(o.Door,''''))), ' --WL02
             + ' LTRIM(RTRIM(ISNULL(o.Externorderkey,''''))) + '' / '' + LTRIM(RTRIM(ISNULL(o.Orderkey,''''))), ' --WL02
             + ' ''+'' + LTRIM(RTRIM(ISNULL(o.Route,''''))) + LTRIM(RTRIM(ISNULL(o.C_Zip,''''))), ISNULL(C6.Long,''''), ISNULL(o.BuyerPO,''''), ISNULL(ORDIF.EcomOrderId,''''), ' --WL02   --WL03   --WL04
             + ' ISNULL(C7.Description,''''),ISNULL(C7.Notes,''''),ISNULL(C7.Long,'''') '   --WL04
            
   IF @b_debug=1          
   BEGIN          
      SELECT @c_SQLJOIN + @c_SQLJOIN2         
      SELECT len(@c_SQLJOIN + @c_SQLJOIN2)   --WL02
   END                  
                
   SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +             
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +             
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +             
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +             
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +             
             +',Col55,Col56,Col57,Col58,Col59,Col60) '            
      
 --SET @c_SQL = @c_SQL + @c_SQLJOIN          
          
 --EXEC sp_executesql @c_SQL  

   SET @c_ExecStatements = @c_SQL + CHAR(13) + @c_SQLJOIN + @c_SQLJOIN2   --WL02
         
   IF @b_debug=1          
   BEGIN          
      SELECT @c_ExecStatements   
      SELECT LEN(@c_ExecStatements)        --WL02
   END    
         
   SET @c_ExecArguments = N' @c_Sparm01    NVARCHAR(60)'    
                          +',@c_Sparm02    NVARCHAR(60)'    
                                       
    
   EXEC sp_ExecuteSql @c_ExecStatements      
                    , @c_ExecArguments    
                    , @c_Sparm01    
                    , @c_Sparm02    
    
     --IF @@ERROR <> 0         
     --BEGIN    
     --  SET @n_continue = 3    
     --  ROLLBACK TRAN    
     --  GOTO EXIT_SP    
     --END   
     --ELSE  
     --BEGIN  
     --    WHILE @@TRANCOUNT > 0  
     --    BEGIN  
     --       COMMIT TRAN  
     --    END  
     -- END            
          
   IF @b_debug=1          
   BEGIN            
      PRINT @c_SQL          
      SELECT * FROM #Result (nolock)       
   END         
  
   DECLARE CUR_SRESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
   SELECT DISTINCT col58,col59  
   FROM   #Result      
   WHERE col58 = @c_Sparm01  
    
   OPEN CUR_SRESULT     
       
   FETCH NEXT FROM CUR_SRESULT INTO @c_Pickslipno,@c_Orderkey  
       
   WHILE @@FETCH_STATUS <> -1    
   BEGIN  
    
      SET @c_col18 = N'常溫'  
      SET @c_col19 = ''  
      
      SELECT TOP 1 @c_col18 = C.long   
      FROM ORDERDETAIL OD WITH (NOLOCK)  
      JOIN SKU S WITH (NOLOCK) ON S.StorerKey=OD.StorerKey AND S.Sku=OD.Sku  
      JOIN CODELKUP C WITH (NOLOCK) ON C.listname='TCATTEMP'  
      AND c.code = s.TemperatureFlag+'_TCAT'  
      WHERE OD.OrderKey=@c_Orderkey  
      ORDER BY s.TemperatureFlag desc  
     
     
      SELECT TOP 1 @c_col19 = C.description   
      FROM ORDERDETAIL OD WITH (NOLOCK)  
      JOIN SKU S WITH (NOLOCK) ON S.StorerKey=OD.StorerKey AND S.Sku=OD.Sku  
      JOIN CODELKUP C WITH (NOLOCK) ON C.listname='POISON'  
      AND c.code = s.busr8  
      WHERE OD.OrderKey=@c_Orderkey  
      ORDER BY s.busr8 DESC  

      UPDATE #Result  
      SET col18 = @c_col18  
         ,col19 = @c_col19  
      WHERE col58 = @c_Pickslipno  
      AND col59 = @c_Orderkey  
  
      FETCH NEXT FROM CUR_SRESULT INTO @c_Pickslipno,@c_Orderkey  
       
   END     
    
   CLOSE CUR_SRESULT  
   DEALLOCATE CUR_SRESULT 

   --WL02 Start
   DECLARE CUR_TrackingNo CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
   SELECT DISTINCT LTRIM(RTRIM(Col02))
   FROM   #Result      
    
   OPEN CUR_TrackingNo     
       
   FETCH NEXT FROM CUR_TrackingNo INTO @c_TrackingNo 
       
   WHILE @@FETCH_STATUS <> -1    
   BEGIN  
      
      SELECT @c_Col31 = LEFT(@c_TrackingNo,4) + '-' + SUBSTRING(@c_TrackingNo,5,4) + '-' + SUBSTRING(@c_TrackingNo,9,4)

      UPDATE #RESULT
      SET Col31 = @c_Col31
      WHERE Col02 = @c_TrackingNo

      FETCH NEXT FROM CUR_TrackingNo INTO @c_TrackingNo
   END     
    
   CLOSE CUR_TrackingNo  
   DEALLOCATE CUR_TrackingNo 
   --WL01 End
              
EXIT_SP:      
    
   SET @d_Trace_EndTime = GETDATE()    
   SET @c_UserName = SUSER_SNAME()    
       
   EXEC isp_InsertTraceInfo     
      @c_TraceCode = 'BARTENDER',    
      @c_TraceName = 'isp_BT_Bartender_TW_LCT_ship_Label_01',    
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
     
   SELECT * FROM #Result (nolock)   
                                    
END -- procedure     

GO
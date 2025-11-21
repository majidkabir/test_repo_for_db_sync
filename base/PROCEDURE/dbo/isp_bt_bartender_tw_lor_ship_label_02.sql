SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/                   
/* Copyright: LFL                                                             */                   
/* Purpose: isp_BT_Bartender_TW_LOR_Ship_Label_02                             */ 
/*          Copy AND modified from isp_BT_Bartender_TW_LCT_Ship_Label_01      */                  
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */
/* 2021-12-29 1.0  WLChooi    Created (WMS-18641)                             */   
/* 2021-12-29 1.0  WLChooi    DevOps Combine Script                           */
/* 2022-06-08 1.1  Mingle     Add col33-39(ML01)                              */
/* 2022-12-09 1.2  CHONGCS    WMS-21299 revised col12 field logic (CS01)      */
/* 2023-01-04 1.3  Mingle     Add col40(ML02)                                 */
/******************************************************************************/                  
                    
CREATE   PROC [dbo].[isp_BT_Bartender_TW_LOR_Ship_Label_02]                        
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
                                
   DECLARE @c_Uccno           NVARCHAR(20),                      
           @c_Sku             NVARCHAR(20),                           
           @n_intFlag         INT,       
           @n_CntRec          INT,      
           @c_SQL             NVARCHAR(MAX),
           @c_SQLSORT         NVARCHAR(MAX),      
           @c_SQLJOIN         NVARCHAR(MAX),
           @c_SQLJOIN2        NVARCHAR(MAX),
           @n_totalcase       INT,  
           @n_sequence        INT,  
           @c_skugroup        NVARCHAR(10), 
           @n_CntSku          INT,  
           @n_TTLQty          INT,  
           @c_Pickslipno      NVARCHAR(20), 
           @c_Orderkey        NVARCHAR(20), 
           @c_Col18           NVARCHAR(60), 
           @c_Col19           NVARCHAR(60),
           @c_Col31           NVARCHAR(80), 
           @c_TrackingNo      NVARCHAR(80),
			  @c_Col40				NVARCHAR(60)
             
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
              
   SET @c_SQL = ''    
   SET @c_Sku = ''   
   SET @c_skugroup = ''      
   SET @n_totalcase = 0    
   SET @n_sequence  = 1   
   SET @n_CntSku = 1    
   SET @n_TTLQty = 0       
     
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
                          
   SET @c_SQLJOIN = +N' SELECT DISTINCT ISNULL(O.route,''''), ' --1
                    + ' CASE WHEN LTRIM(RTRIM(ISNULL(O.TrackingNo,''''))) = '''' THEN ISNULL(CT.TrackingNo,'''') ELSE ISNULL(O.trackingno,'''') END, ' --2
                    + ' ISNULL(O.Orderdate,''''), ISNULL(O.deliverydate,''''),'       --4  
                    + ' CASE WHEN ISNULL(C.Description,'''') <> '''' THEN ISNULL(C.Description,'''') ELSE ISNULL(C4.Description,'''') END,' --5
                    + ' ISNULL(C1.Short,''''),'  --6
                    + ' ISNULL(RTRIM(O.C_Address1),'''')+ISNULL(RTRIM(O.C_Address2),'''')+ISNULL(RTRIM(O.C_Address3),'''')+ISNULL(RTRIM(O.C_Address4),''''),'  --7  
                    + ' ISNULL(O.C_Company,''''), '   --9  
                    + ' ISNULL(C5.Notes,''''), ' --9
                    + ' CASE WHEN LEN(C2.UDF01) > 0 THEN ISNULL(C2.UDF01,'''') ELSE ISNULL(C5.Long,'''') END, CASE WHEN LEN(C2.Long) > 0 THEN ISNULL(C2.Long,'''') ELSE ISNULL(C5.UDF03,'''') END,'--11
                    + ' ISNULL(RTRIM(substring(O.Notes,1,80)),''''),'--+ISNULL(RTRIM(O.Notes2),''''),' --12     --CS01       
                    + ' ISNULL(O.Externorderkey,''''), ISNULL(C1.Long,''''),'   --14
                    + N' CASE WHEN ISNULL(ORDIF.OrderInfo03,'''') = ''COD'' THEN ISNULL(CAST(ORDIF.payableamount AS NVARCHAR(30)),0)  ELSE N''不收款'' END, ' --15      
                    + ' ISNULL(O.C_Zip,''''),ISNULL(C3.Long,''60CM''),'''','''',ISNULL(ORDIF.OrderInfo05,''''),'     --20                            
                    + ' ISNULL(O.c_phone1,''''),ISNULL(O.c_phone2,''''),ISNULL(O.C_Contact1,''''),ISNULL(O.Orderkey,''''),ORDIF.OrderInfo04, PD.CartonNo, '  --26  
                    + ' ISNULL(CT.TrackingNo,''''), '  --27 
                    + ' LTRIM(RTRIM(ISNULL(O.Route,''''))) + ''-'' + LEFT(LTRIM(RTRIM(ISNULL(O.C_Zip,''''))),3) + ''-'' + SUBSTRING(LTRIM(RTRIM(ISNULL(O.C_Zip,''''))),4,2) + ''-'' + LTRIM(RTRIM(ISNULL(O.Door,''''))), ' --28 
                    + ' LTRIM(RTRIM(ISNULL(O.Externorderkey,''''))) + '' / '' + LTRIM(RTRIM(ISNULL(O.Orderkey,''''))), ' --29   
                    + ' ''+'' + LTRIM(RTRIM(ISNULL(O.Route,''''))) + LTRIM(RTRIM(ISNULL(O.C_Zip,''''))),'  --30    
                    + ' '''',ISNULL(C6.Long,''''),O.Buyerpo,ORDIF.EcomOrderID,ISNULL(C7.description,''''),ISNULL(C7.Notes,''''),ISNULL(C7.Long,''''),Getdate(),Getdate()+1,'''','   --40	--ML01            
                    + ' '''','''','''','''','''','''','''','''','''','''', '  --50         
                    + ' '''','''','''','''','''','''','''',PD.Pickslipno,O.Orderkey,'''' ' + CHAR(13)   --60                        
                    + ' FROM PackHeader AS PH WITH (NOLOCK)'   + CHAR(13)         
                    + ' JOIN PackDetail AS PD WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno'   + CHAR(13)          
                    + ' JOIN ORDERS AS O WITH (NOLOCK) ON O.Orderkey = PH.Orderkey '   + CHAR(13)           
                    + ' LEFT JOIN Storer ST WITH (NOLOCK) ON ST.Storerkey = O.Storerkey '   + CHAR(13)                        
                    + ' JOIN SKU S WITH (NOLOCK) ON S.Storerkey = PD.Storerkey AND S.sku = PD.sku'   + CHAR(13)       
                    --+ ' LEFT JOIN CARTONTRACK CT WITH (NOLOCK) ON CT.Labelno = O.Orderkey AND ISNULL(NULLIF(CT.CARRIERREF2,''''),''1'') = cast(PD.CartonNo as nvarchar(20))'   + CHAR(13)	--ML01     
					     + ' LEFT JOIN CARTONTRACK CT WITH (NOLOCK) ON CT.labelno=O.orderkey AND PD.CartonNo = CASE WHEN ISNUMERIC(CT.CARRIERREF2) = 1 THEN ISNULL(NULLIF(CT.CARRIERREF2,''''),''1'') ELSE PD.CartonNo END' --ML01
                    + ' LEFT JOIN OrderInfo ORDIF WITH (NOLOCK) ON ORDIF.Orderkey = O.Orderkey '   + CHAR(13)            
                    + ' LEFT JOIN PACKINFO PI WITH (NOLOCK) ON PI.Pickslipno = PH.Pickslipno  '   + CHAR(13)       
                    + ' LEFT JOIN CODELKUP C   WITH (NOLOCK) ON C.Listname = ''Exparvtime'' AND C.Code=O.Shipperkey+''_''+ORDIF.OrderInfo04 AND C.Storerkey = O.Storerkey'   + CHAR(13)        
                    + ' LEFT JOIN CODELKUP C1   WITH (NOLOCK) ON C1.Listname = ''CarrierInf'' AND C1.Code=''TCAT_ORD'' AND C1.Storerkey = O.Storerkey AND C1.Code2 = O.OrderGroup'   + CHAR(13)        
                    + ' LEFT JOIN CODELKUP C2   WITH (NOLOCK) ON C2.Listname = ''TCATLABEL'' AND C2.Code=ORDIF.platform AND C2.Storerkey = O.Storerkey'   + CHAR(13)        
                    + ' LEFT JOIN CODELKUP C3   WITH (NOLOCK) ON C3.Listname = ''Cartontype'' AND C3.Code=RTRIM(PI.cartontype)+''_''+RTRIM(O.Shipperkey) AND C3.Storerkey = O.Storerkey'   + CHAR(13)       
                    + ' LEFT JOIN CODELKUP C4   WITH (NOLOCK) ON C4.Listname = ''Exparv2'' AND C4.Code=O.Shipperkey AND C4.Storerkey = O.Storerkey AND C4.Short=''4'' '   + CHAR(13)        
                    + ' LEFT JOIN CODELKUP C5   WITH (NOLOCK) ON C5.Listname = ''COURIERADR'' AND C5.Code = O.Shipperkey AND C5.Storerkey = O.Storerkey AND C5.Code2 = '''' '   + CHAR(13)        
                    + ' LEFT JOIN CODELKUP C6   WITH (NOLOCK) ON C6.Listname = ''VFTCATINFO'' AND C6.Code = O.OrderGroup AND C6.Storerkey = O.Storerkey '   + CHAR(13) 
				        + ' LEFT JOIN CODELKUP C7   WITH (NOLOCK) ON C7.Listname = ''WebsitInfo'' AND C7.Code = ORDIF.Storename AND C7.Storerkey = O.Storerkey '   + CHAR(13)	--ML01
                    + ' JOIN FACILITY F WITH (NOLOCK) ON F.facility = O.facility '  

   SET @c_SQLJOIN2 = N' WHERE PD.Pickslipno = @c_Sparm01 '     
                    + ' AND PD.Labelno = @c_Sparm02 '      
                    + ' GROUP BY ISNULL(O.route,''''), '
                    + ' CASE WHEN LTRIM(RTRIM(ISNULL(O.TrackingNo,''''))) = '''' THEN ISNULL(CT.TrackingNo,'''') ELSE ISNULL(O.TrackingNo,'''') END, ' 
                    + ' ISNULL(O.Orderdate,''''),ISNULL(O.deliverydate,''''),'       --4  
                    + ' CASE WHEN ISNULL(C.Description,'''') <> '''' THEN ISNULL(C.Description,'''') ELSE ISNULL(C4.Description,'''') END,'    
                    + ' ISNULL(C1.Short,''''),'  
                    + ' ISNULL(RTRIM(O.C_Address1),'''')+ISNULL(RTRIM(O.C_Address2),'''')+ISNULL(RTRIM(O.C_Address3),'''')+ISNULL(RTRIM(O.C_Address4),''''),'  --7  
                    + ' ISNULL(O.C_Company,''''), '  
                    + ' ISNULL(C5.Notes,''''), '  
                    + ' CASE WHEN LEN(C2.UDF01) > 0 THEN ISNULL(C2.UDF01,'''') ELSE ISNULL(C5.Long,'''') END,CASE WHEN LEN(C2.Long) > 0 THEN ISNULL(C2.Long,'''') ELSE ISNULL(C5.UDF03,'''') END,'  
                   -- + ' ISNULL(RTRIM(O.Notes),'''')+ISNULL(RTRIM(O.notes2),''''),'            --CS01
                    + ' ISNULL(RTRIM(substring(O.Notes,1,80)),''''),'--+ISNULL(RTRIM(O.Notes2),''''),'     --CS01
                    + ' ISNULL(O.Externorderkey,''''),ISNULL(C1.Long,''''),'  
                    + N'CASE WHEN ISNULL(ORDIF.OrderInfo03,'''') = ''COD'' THEN ISNULL(CAST(ORDIF.payableamount AS NVARCHAR(30)),0)  ELSE N''不收款'' END, '   
                    + ' ISNULL(O.C_Zip,''''),ISNULL(C3.Long,''60CM''),ISNULL(ORDIF.OrderInfo05,''''),ISNULL(O.c_phone1,''''),ISNULL(O.c_phone2,''''),PD.Pickslipno,O.Orderkey, '  
                    + ' ISNULL(O.C_Contact1,''''),ISNULL(O.Orderkey,''''),ORDIF.OrderInfo04,'  
                    + ' PD.CartonNo,ISNULL(CT.TrackingNo,''''), '
                    + ' LTRIM(RTRIM(ISNULL(O.Route,''''))) + ''-'' + LEFT(LTRIM(RTRIM(ISNULL(O.C_Zip,''''))),3) + ''-'' + SUBSTRING(LTRIM(RTRIM(ISNULL(O.C_Zip,''''))),4,2) + ''-'' + LTRIM(RTRIM(ISNULL(O.Door,''''))), ' 
                    + ' LTRIM(RTRIM(ISNULL(O.Externorderkey,''''))) + '' / '' + LTRIM(RTRIM(ISNULL(O.Orderkey,''''))), ' 
                    + ' ''+'' + LTRIM(RTRIM(ISNULL(O.Route,''''))) + LTRIM(RTRIM(ISNULL(O.C_Zip,''''))), ISNULL(C6.Long,''''), '    
					     + ' O.Buyerpo,ORDIF.EcomOrderID,ISNULL(C7.description,''''),ISNULL(C7.Notes,''''),ISNULL(C7.Long,'''') '	--ML01
            
   IF @b_debug=1          
   BEGIN          
      SELECT @c_SQLJOIN + @c_SQLJOIN2         
      SELECT LEN(@c_SQLJOIN + @c_SQLJOIN2)   
   END                  
                
   SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +             
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +             
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +             
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +             
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +             
             +',Col55,Col56,Col57,Col58,Col59,Col60) '            

   SET @c_ExecStatements = @c_SQL + CHAR(13) + @c_SQLJOIN + @c_SQLJOIN2   
         
   IF @b_debug=1          
   BEGIN          
      SELECT @c_ExecStatements   
      SELECT LEN(@c_ExecStatements)        
   END    
         
   SET @c_ExecArguments = N' @c_Sparm01    NVARCHAR(60)'    
                          +',@c_Sparm02    NVARCHAR(60)'    
                                       
    
   EXEC sp_ExecuteSql @c_ExecStatements      
                    , @c_ExecArguments    
                    , @c_Sparm01    
                    , @c_Sparm02    
 
   IF @b_debug=1          
   BEGIN            
      PRINT @c_SQL          
      SELECT * FROM #Result (NOLOCK)       
   END         
  
   DECLARE CUR_SRESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
   SELECT DISTINCT Col58,Col59  
   FROM   #Result      
   WHERE Col58 = @c_Sparm01  
    
   OPEN CUR_SRESULT     
       
   FETCH NEXT FROM CUR_SRESULT INTO @c_Pickslipno, @c_Orderkey  
       
   WHILE @@FETCH_STATUS <> -1    
   BEGIN  
      SET @c_Col18 = N'常溫'  
      SET @c_Col19 = ''  
      
      SELECT TOP 1 @c_Col18 = C.Long   
      FROM ORDERDETAIL OD WITH (NOLOCK)  
      JOIN SKU S WITH (NOLOCK) ON S.Storerkey = OD.Storerkey AND S.Sku = OD.Sku  
      JOIN CODELKUP C WITH (NOLOCK) ON C.Listname = 'TCATTEMP'  
                                   AND C.code = S.TemperatureFlag + '_TCAT'  
      WHERE OD.Orderkey = @c_Orderkey  
      ORDER BY S.TemperatureFlag DESC  
     
      SELECT TOP 1 @c_Col19 = C.[Description]   
      FROM ORDERDETAIL OD WITH (NOLOCK)  
      JOIN SKU S WITH (NOLOCK) ON S.Storerkey = OD.Storerkey AND S.Sku = OD.Sku  
      JOIN CODELKUP C WITH (NOLOCK) ON C.Listname = 'POISON'  
                                   AND C.Code = S.BUSR8  
      WHERE OD.Orderkey = @c_Orderkey  
      ORDER BY S.BUSR8 DESC  

      SELECT TOP 1 @c_Col40 = refno2
      FROM PACKDETAIL(NOLOCK)
      WHERE PICKSLIPNO = @c_Pickslipno	--ML02

      UPDATE #Result  
      SET Col18 = @c_Col18  
         ,Col19 = @c_Col19  
	 ,Col40 = @c_Col40	--ML02
      WHERE Col58 = @c_Pickslipno  
      AND Col59 = @c_Orderkey  
  
      FETCH NEXT FROM CUR_SRESULT INTO @c_Pickslipno, @c_Orderkey  
   END     
   CLOSE CUR_SRESULT  
   DEALLOCATE CUR_SRESULT 

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
              
EXIT_SP:      
    
   SET @d_Trace_EndTime = GETDATE()    
   SET @c_UserName = SUSER_SNAME()    
       
   EXEC isp_InsertTraceInfo     
      @c_TraceCode = 'BARTENDER',    
      @c_TraceName = 'isp_BT_Bartender_TW_LOR_Ship_Label_02',    
      @c_starttime = @d_Trace_StartTime,    
      @c_endtime = @d_Trace_EndTime,    
      @c_step1 = @c_UserName,    
      @c_step2 = '',    
      @c_step3 = '',    
      @c_step4 = '',    
      @c_step5 = '',    
      @c_Col1 = @c_Sparm01,     
      @c_Col2 = @c_Sparm02,    
      @c_Col3 = @c_Sparm03,    
      @c_Col4 = @c_Sparm04,    
      @c_Col5 = @c_Sparm05,    
      @b_Success = 1,    
      @n_Err = 0,    
      @c_ErrMsg = ''                
     
   SELECT * FROM #Result (nolock)   
                                    
END -- procedure     

GO
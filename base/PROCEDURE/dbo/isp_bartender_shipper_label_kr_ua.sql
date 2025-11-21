SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: [isp_Bartender_Shipper_Label_KR_UA]                               */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2016-11-12 1.0  CSCHONG    Created (WMS-560)                               */    
/* 2017-01-05 1.1  CSCHONG    Mapping field update (CS01)                     */   
/* 2017-01-09 1.2  CSCHONG    Mapping field update (CS02)                     */   
/* 2017-01-11 1.3  CSCHONG    Add new mapping (CS03)                          */   
/* 2017-01-24 1.4  TLTING01   SET ANSI NULLS Option                           */     
/* 2018-04-20 1.5  CSCHONG    Dynamic SQL (CS04)                              */     
/* 2021-04-02 1.6  CSCHONG    WMS-16024 PB-Standardize TrackingNo (CS05)      */           
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_Bartender_Shipper_Label_KR_UA]                      
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
      @c_ReceiptKey      NVARCHAR(10),                    
      @c_ExternOrderKey  NVARCHAR(10),              
      @c_Deliverydate    DATETIME,              
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
           @c_Col16            NVARCHAR(80),
           @c_col17            NVARCHAR(80),
           @c_col18            NVARCHAR(80),
           @c_Col19            NVARCHAR(80),
           @c_Col20            NVARCHAR(80),
           @c_Orderkey         NVARCHAR(20),
           @c_ItemDescr        NVARCHAR(80),
           @n_ID               INT,     
           @c_ExecArguments   NVARCHAR(4000)              --(CS04)  
  
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
     
      CREATE TABLE [#OrdItem] (             
      [ID]         [INT] IDENTITY(1,1) NOT NULL,
      [Orderkey]   NVARCHAR(20) NULL,   
      [SKU]        NVARCHAR(30) NULL,  
      [ItemDescr]  NVARCHAR(80) NULL)   
              
        IF @b_debug=1        
         BEGIN        
            PRINT 'start'          
         END        
  SET @c_SQLJOIN = +' SELECT DISTINCT ORD.C_Contact1,ORD.c_phone1,(ORD.C_Address1 + ORD.C_Address2) AS Add1,'+ CHAR(13) +     --3     
             + ' ORD.C_Zip,(STO.City +  '' ''   + STO.Address3 +  '' ''   + STO.Address2) As Add2,'      --5
             + ' (SUBSTRING(ORD.C_Contact1,1,LEN(ORD.C_Contact1) - LEN(RIGHT(ORd.C_Contact1, 1))) + ''*''),SUBSTRING(ORD.C_Phone2,1,LEN(ORD.C_Phone2) - LEN(RIGHT(ORD.C_Phone2, 4))) + ''****'',' --7
           --  + '(Substring(CT.TrackingNo,1,4) + ''-'' + Substring(CT.TrackingNo,5,4)  +''-'' +  Substring(CT.TrackingNo,9,4) ) AS TrackNo,'     --8
             + '(Substring(ORD.trackingno,1,4) + ''-'' + Substring(ORD.trackingno,5,4)  +''-'' +  Substring(ORD.trackingno,9,4) ) AS TrackNo,'     --8  --(CS01) --(CS05)
             + 'ORD.trackingno,ORD.M_country,ORD.M_Address3,ORD.M_Zip,ORD.M_Address4,STO.Phone1,STO.Company, '                       --15     --(CS01)  --(CS05)
             + CHAR(13) +      
             + ' '''','''','''','''','''','         --20      
             + ' ORD.C_Contact2,ORD.BuyerPO,ORD.C_Phone2,ORD.ExternOrderkey,'''','         --25                --(CS03)
             + ' '''','''','''','''','''','         --30 
             + ' '''','''','''','''','''','''','''','''','''','''','   --40       
             + ' '''','''','''','''','''','''','''','''','''','''', '  --50       
             + ' '''','''','''','''','''','''','''','''','''' , @c_Sparm01 '    --60           --(CS04)
             + CHAR(13) +            
            -- + ' FROM CartonShipmentDetail CSD WITH (NOLOCK) '
             + ' FROM ORDERS ORD WITH (NOLOCK) '--ON ORD.Externorderkey = CSD.Externorderkey'       
             --+ ' FULL JOIN PACKHEADER PACKH WITH (NOLOCK) ON PACKH.OrderKey= ORD.OrderKey'  
             --+ ' FULL JOIN PACKDETAIL PACKDET WITH (NOLOCK) ON PACKH.Pickslipno = PACKDET.Pickslipno' 
             --+ ' LEFT JOIN CARTONTRACK CT WITH (NOLOCK) ON CT.labelno = ORD.Orderkey'                 --(CS01)
             + ' JOIN STORER STO WITH (NOLOCK) ON ORD.Storerkey=STO.Storerkey'
             + ' WHERE ORD.Orderkey = @c_Sparm01 '                                                      --(CS04)
             --+ ' WHERE CT.TrackingNumber =''' + @c_Sparm01+ ''' '   
             --+ ' AND CT.labelno =  ''' + @c_Sparm02+ ''' '        
                       
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
   
    SET @c_ExecArguments = N'   @c_Sparm01           NVARCHAR(80)'
                           + ', @c_Sparm02           NVARCHAR(80) '     
          
                         
                         
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @c_Sparm01    
                        , @c_Sparm02
   
   
      IF @b_debug=1        
   BEGIN          
       PRINT @c_SQL          
   END  
   
   
   
   INSERT INTO #OrdItem (Orderkey,sku,ItemDescr)
   --SELECT DISTINCT TOP 5 OD.Orderkey,OD.sku,(LTRIM(RTRIM(S.descr)) + ' ' + cast(OD.originalqty as nvarchar(10)) + N'?')  --(CS02)
  -- FROM OrderDetail OD (NOLOCK)              --(CS02) 
  SELECT DISTINCT TOP 5 PDET.Orderkey,PDET.sku,(LTRIM(RTRIM(S.descr)) + ' ' + cast(PDET.qty as nvarchar(10)) + N'개')   --(CS02)
   FROM PICKDETAIL PDET (NOLOCK)               --(CS02)
   JOIN SKU S (NOLOCK) ON S.Sku=PDET.Sku AND S.Storerkey=PDET.StorerKey
   WHERE PDET.OrderKey   =  @c_Sparm01
   
   IF @b_debug=1        
   BEGIN   
   	SELECT * FROM #OrdItem (NOLOCK)    
      SELECT * FROM #Result (nolock)        
   END        
   
   
   SET @c_Col16 = ''
   SET @c_col17 = ''
   SET @c_col18 = ''
   SET @c_col19 = '' 
   SET @c_col20 = ''  
      
   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT ID,Orderkey,ItemDescr   
   FROM   #OrdItem    
   WHERE Orderkey = @c_Sparm01 
   ORDER BY ID
  
   OPEN CUR_RESULT   
     
   FETCH NEXT FROM CUR_RESULT INTO @n_ID,@c_Orderkey,@c_ItemDescr    
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN   
   	
   	
   IF @n_ID = 1
   BEGIN
   	SET @c_Col16 = CONVERT(NVARCHAR(1),@n_Id) + ')' + ' ' + @c_ItemDescr + ' '--+ ','
   END
   ELSE IF @n_ID = 2
   BEGIN
   	SET @c_Col17 = CONVERT(NVARCHAR(1),@n_Id) + ')' + ' ' + @c_ItemDescr + ' ' --+ ','
   END
   ELSE IF @n_ID = 3
   BEGIN
   	SET @c_Col18 = CONVERT(NVARCHAR(1),@n_Id) + ')' + ' ' + @c_ItemDescr + ' ' --+ ','
   END
   ELSE IF @n_ID = 4
   BEGIN
   	SET @c_Col19 = CONVERT(NVARCHAR(1),@n_Id) + ')' + ' ' + @c_ItemDescr + ' ' --+ ','
   END
   ELSE IF @n_ID = 5
   BEGIN
   	SET @c_Col20 = CONVERT(NVARCHAR(1),@n_Id) + ')' + ' ' + @c_ItemDescr + ' ' --+ ','
   END
   	
   FETCH NEXT FROM CUR_RESULT INTO @n_ID,@c_Orderkey,@c_ItemDescr  
   END  	  
   
   CLOSE CUR_RESULT
   DEALLOCATE CUR_RESULT  
   
   UPDATE #Result
   SET Col16 = @c_Col16,
       Col17 = @c_Col17,
       Col18 = @c_Col18,
       Col19 = @c_Col19,
       Col20 = @c_Col20
   WHERE col60 =@c_Sparm01       
      
   SELECT * FROM #Result (nolock)        
            
   EXIT_SP:    
  
 /*     SET @d_Trace_EndTime = GETDATE()  
      SET @c_UserName = SUSER_SNAME()  
     
      EXEC isp_InsertTraceInfo   
         @c_TraceCode = 'BARTENDER',  
         @c_TraceName = '[isp_Bartender_Shipper_Label_KR_UA]',  
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
   
  */
                                  
   END -- procedure   



GO
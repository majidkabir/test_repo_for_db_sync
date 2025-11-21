SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
  
/******************************************************************************/                   
/* Copyright: IDS                                                             */                   
/* Purpose: isp_Bartender_TH_TMSCTNLBL_GetParm                                */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */                   
/* 2018-04-06 1.0  CSCHONG    Created (WMS-4428)                              */                   
/******************************************************************************/                  
        
CREATE PROC [dbo].[isp_Bartender_TH_TMSCTNLBL_GetParm]                        
(  @parm01            NVARCHAR(250),                
 @parm02            NVARCHAR(250),                
 @parm03            NVARCHAR(250),                
 @parm04            NVARCHAR(250),                
 @parm05            NVARCHAR(250),                
 @parm06            NVARCHAR(250),                
 @parm07            NVARCHAR(250),                
 @parm08            NVARCHAR(250),                
 @parm09            NVARCHAR(250),                
 @parm10            NVARCHAR(250),          
 @b_debug             INT = 0                           
)                        
AS                        
BEGIN                        
 SET NOCOUNT ON                   
 SET ANSI_NULLS OFF                  
 SET QUOTED_IDENTIFIER OFF                   
 SET CONCAT_NULL_YIELDS_NULL OFF                                       
            
 DECLARE                    
  @c_OrderKey        NVARCHAR(10),                      
  @c_PrintMbol       NVARCHAR(1),      
  @c_printbyOrder    NVARCHAR(1),            
  @c_Deliverydate    DATETIME,                
  @n_intFlag         INT,       
  @n_CntRec          INT,      
  @c_SQL             NVARCHAR(4000),          
  @c_SQLSORT         NVARCHAR(4000),          
  @c_SQLJOIN         NVARCHAR(4000),  
  @c_condition1      NVARCHAR(150) ,  
  @c_condition2      NVARCHAR(150),  
  @c_SQLGroup        NVARCHAR(4000),  
  @c_SQLOrdBy        NVARCHAR(150),  
  @c_ExecArguments   NVARCHAR(4000),  
  @c_SQLInsert       NVARCHAR(4000),  
  @c_parm01          NVARCHAR(250),  
  @c_parm02          NVARCHAR(250),  
  @c_parm03          NVARCHAR(250),  
  @c_parm09          NVARCHAR(250),  
  @c_parm10          NVARCHAR(250),  
  @n_parm04          INT,  
  @c_parm06          NVARCHAR(250),  
  @c_parm08          NVARCHAR(250),  
  @n_ttlctn          INT,  
  @n_Skuctn          INT,  
  @n_Cartonno        INT,  
  @n_ctnrec          INT,  
  @c_presku          NVARCHAR(20),  
  @n_FQty            INT,  
  @n_CQty            INT,  
  @c_FullCtn         NVARCHAR(10),  
  @c_uom             NVARCHAR(10),  
  @n_CtnSKU          INT,  
  @c_Fullpallet      NVARCHAR(10),  
  @n_PLTQty          INT,  
  @n_CPLTQty         INT,  
  @n_rowno           INT,  
  @c_refno           NVARCHAR(30),  
  @c_PDID            NVARCHAR(30),  
  @n_parm02          INT,  
  @c_preorderkey     NVARCHAR(20),  
  @n_OrderRow        INT,  
  @c_PickslipExist   NVARCHAR(1)  
  
    
    
    
  DECLARE @d_Trace_StartTime   DATETIME,     
     @d_Trace_EndTime    DATETIME,    
     @c_Trace_ModuleName NVARCHAR(20),     
     @d_Trace_Step1      DATETIME,     
     @c_Trace_Step1      NVARCHAR(20),    
     @c_UserName         NVARCHAR(20),  
     @n_cntsku           INT,  
     @c_mode             NVARCHAR(1),  
     @c_sku              NVARCHAR(20),  
     @c_getOrderkey      NVARCHAR(20),  
     @c_getUdef09        NVARCHAR(30),  
     @c_key01            NVARCHAR(50),  
     @n_lineCtn          INT,  
     @n_LineStart        INT  
       
        
    
 SET @d_Trace_StartTime = GETDATE()    
 SET @c_Trace_ModuleName = ''    
      
  -- SET RowNo = 0               
  SET @c_SQL = ''     
  SET @c_mode = '0'     
  SET @c_getOrderkey = ''  
  SET @c_getUdef09 = ''    
  SET @c_SQLJOIN = ''          
  SET @c_condition1 = ''  
  SET @c_condition2= ''  
  SET @c_SQLOrdBy = ''  
  SET @c_SQLGroup = ''  
  SET @c_key01 = ''  
  SET @c_PrintMbol = 'N'  
  SET @c_printbyOrder = 'N'  
  SET @n_Cartonno = 1  
  SET @n_ttlctn = 1  
  SET @n_LineStart = 1  
  SET @c_presku = ''  
  SET @c_FullCtn   = 'N'  
  SET @n_CtnSKU = 1  
  SET @c_Fullpallet = 'N'  
  SET @c_PickslipExist = 'N'  
    
  CREATE TABLE #TEMPRESULT  (  
   PARM01       NVARCHAR(80),   
   PARM02       NVARCHAR(80),   
   PARM03       NVARCHAR(80),   
   PARM04       NVARCHAR(80),   
   PARM05       NVARCHAR(80),   
   PARM06       NVARCHAR(80),   
   PARM07       NVARCHAR(80),   
   PARM08       NVARCHAR(80),   
   PARM09       NVARCHAR(80),   
   PARM10       NVARCHAR(80),   
   Key01        NVARCHAR(80),  
   Key02        NVARCHAR(80),  
   Key03        NVARCHAR(80),  
   Key04        NVARCHAR(80),  
   Key05        NVARCHAR(80)  
     
  )  
    
    
  IF EXISTS (SELECT 1 FROM ORDERS WITH ( NOLOCK)  
     WHERE orderkey = @parm01)  
  BEGIN  
   SET @c_printbyOrder = 'Y'  
   SET @c_getOrderkey = @parm01  
   SET @c_condition2 = ' AND OH.Orderkey =  @c_getOrderkey'  
     
   IF EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK)  
      WHERE OrderKey = @c_getOrderkey)  
   BEGIN  
   SET @c_PrintMbol='N'  
   SELECT @parm01 = PH.Pickslipno  
   FROM PACKHEADER PH (NOLOCK)  
   WHERE PH.Orderkey =  @c_getOrderkey  
     
     IF ISNULL(@parm02,'') = ''  
     BEGIN  
       SET @parm02='1'  
     END   
     
     IF ISNULL(@parm03,'') = ''  
     BEGIN  
       SET @parm03='999'  
     END   
     
   END             
   ELSE  
   BEGIN  
   SET @c_PrintMbol='Y'  
   SELECT @parm01 = mbolkey  
   FROM ORDERS (NOLOCK)  
   WHERE orderkey = @c_getOrderkey  
  
     IF ISNULL(@parm02,'') = ''  
     BEGIN  
       SET @parm02='1'  
     END   
     
     IF ISNULL(@parm03,'') = ''  
     BEGIN  
       SET @parm03='999'  
     END   
  
   END   
     
     
  END  
    
  IF EXISTS (SELECT 1 FROM MBOL WITH (NOLOCK)  
     WHERE mbolkey = @parm01)  
  BEGIN  
  SET @c_PrintMbol='Y'  
  SET @c_key01 = 'mbolkey'  
  SET @c_condition1 = ' WHERE  OH.mbolkey = @Parm01' + CHAR(13) +  
       ' AND PD.UOM IN (''1'',''2'',''6'') '  
  SET @c_SQLGroup =' GROUP BY OH.mbolkey,PD.sku,OH.Orderkey,pd.id,p.CaseCnt,p.Pallet,PD.UOM'                      
  SET @c_SQLOrdBy = ' Order BY OH.Orderkey,PD.sku'  
  END  
  ELSE IF EXISTS (SELECT 1 FROM PACKHEADER PH WITH (NOLOCK)  
        WHERE PH.PickSlipNo = @parm01)  
  BEGIN  
  SET @c_PrintMbol='N'  
  SET @c_key01='Pickslipno'  
  SET @c_condition1 =  ' WHERE PH.Pickslipno = @Parm01 '+ CHAR(13) +  
           ' AND PD.CartonNo >= CONVERT(INT,@Parm02) AND PD.CartonNo <= CONVERT(INT,@Parm03)' + CHAR(13)   
  SET @c_SQLOrdBy = ' Order By PH.Pickslipno,PD.cartonno'  
  END   
 -- ELSE IF EXISTS (SELECT 1    
   
   
  --IF @c_printbyOrder = 'Y'  
  --BEGIN  
  -- IF EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK)  
  --            WHERE @c_OrderKey = @parm01)  
  --  BEGIN  
  --   SET @c_PrintMbol = 'N'  
  --  END            
  --  ELSE  
  --  BEGIN  
  --   SET @c_PrintMbol = 'Y'  
  --  END   
  --END  
    
    
  SET @c_SQLInsert = ''  
  SET @c_SQLInsert ='INSERT INTO #TEMPRESULT (PARM01,PARM02,PARM03,PARM04,PARM05,PARM06,PARM07,PARM08,PARM09,PARM10, ' + CHAR(13) +  
                    ' Key01,Key02,Key03,Key04,Key05)'  
    
  SET @c_ExecArguments = ''  
    
  IF @c_PrintMbol = 'Y'  
  BEGIN  
   SET @c_SQLJOIN = ' SELECT DISTINCT PARM1=OH.mbolkey,PARM2= PD.sku,PARM3=OH.Orderkey,PARM4='''',PARM5= '''',' + CHAR(13) +  
       ' PARM6= '''',PARM7= '''',PARM8='''', ' + CHAR(13) +  
       ' PARM9=case when PD.UOM IN (''1'',''2'') THEN p.casecnt ELSE  isnull(sum(pd.qty)/nullif(pallet,0),0) end,PARM10=pd.id,' + CHAR(13) +  
       ' Key1=@c_key01,Key2=''orderkey'',Key3='''',Key4='''',Key5='''' ' + CHAR(13) +  
       ' FROM MBOL MB WITH (NOLOCK) ' + CHAR(13) +  
       ' JOIN ORDERS OH (NOLOCK) ON OH.MBOLKey = MB.MbolKey ' + CHAR(13) +  
       ' JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey=OH.OrderKey ' + CHAR(13) +  
       ' JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.OrderKey= OD.OrderKey ' + CHAR(13) +  
       '       AND PD.OrderLineNumber=OD.OrderLineNumber ' + CHAR(13) +  
       '       AND PD.Sku=OD.Sku and PD.storerkey = OD.storerkey ' + CHAR(13) +  
       ' JOIN PACK P WITH (NOLOCK) ON p.PackKey=pd.PackKey '  
  END  
  ELSE  
  BEGIN   
  SET @c_SQLJOIN = ' SELECT DISTINCT PARM1=PH.Pickslipno,PARM2=PD.CartonNo,PARM3=OH.Orderkey,PARM4='''',PARM5= '''',' + CHAR(13) +  
       ' PARM6= '''',PARM7= '''',PARM8='''',PARM9='''',PARM10='''',Key1=@c_key01,Key2=''orderkey'',Key3='''',Key4='''',Key5='''' ' + CHAR(13) +  
       ' FROM PACKHEADER PH WITH (NOLOCK)  ' + CHAR(13) +  
       ' JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickslipNo)' + CHAR(13) +  
       ' JOIN ORDERS     OH WITH (NOLOCK) ON (PH.Orderkey = OH.Orderkey)'+ CHAR(13)   
       --  ' WHERE PH.Pickslipno = @Parm01 '+ CHAR(13) +  
       --  ' AND PD.CartonNo >= CONVERT(INT,@Parm02) AND PD.CartonNo <= CONVERT(INT,@Parm03)' + CHAR(13) +  
      --   ' Order By PH.Pickslipno,PD.cartonno '  
  
  
  END  
    
    SET @c_ExecArguments = N'@parm01          NVARCHAR(80),'  
                         + ' @parm02          NVARCHAR(80),'   
                         + ' @parm03          NVARCHAR(80),'  
                         + ' @c_key01         NVARCHAR(50),'  
                         + ' @c_getOrderkey   NVARCHAR(20)'  
           
     
 SET @c_SQL = @c_SQLInsert + CHAR(13) + @c_SQLJOIN + CHAR(13) + @c_condition1 + CHAR(13) + @c_condition2 + CHAR(13) + @c_SQLGroup + CHAR(13) + @c_SQLOrdBy  
    
  IF @b_debug=1  
  BEGIN  
    SELECT @c_SQL  
    SELECT @parm01 '@parm01', @parm02 '@parm02',@parm03 '@parm03'  
  END    
    
  EXEC sp_executesql         
           @c_SQL    
         , @c_ExecArguments    
         , @parm01    
         , @parm02   
         , @parm03   
         , @c_key01  
         , @c_getOrderkey  
           
   IF @b_debug=1  
   BEGIN                
    SELECT @c_PrintMbol '@c_PrintMbol'  
   END                
           
   IF @c_PrintMbol='Y'  
   BEGIN  
      
    SET @c_preorderkey = ''  
      
     DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
     SELECT DISTINCT Parm01,PARM02,parm03,PARM09,parm10     
     FROM  #TEMPRESULT   
     WHERE PARM01 = @parm01  
     AND PARM04='' AND PARM05=''     
    
     OPEN CUR_RESULT     
     
     FETCH NEXT FROM CUR_RESULT INTO @c_parm01,@c_parm02,@c_parm03 ,@c_parm09,@c_parm10   
     
     WHILE @@FETCH_STATUS <> -1    
     BEGIN     
     
     
         SET @n_ttlctn = 1  
         SET @n_Cartonno = 1  
         SET @n_Skuctn  = 1  
         SET @n_lineCtn = 1  
         SET @n_ctnrec = 0  
         SET @c_presku = @c_parm02  
         SET @n_PLTQty = FLOOR(CAST(@c_parm09 AS FLOAT))  
         SET @n_CPLTQty = CEILING(CAST(@c_parm09 AS FLOAT))  
         SET @c_Fullpallet = 'N'  
           
         SELECT @n_CntRec = COUNT(1)  
         FROM #TEMPRESULT AS t  
         WHERE t.PARM01 = @c_parm01  
         AND t.PARM02 = @c_parm02  
         AND t.PARM03= @c_parm03  
         AND t.PARM10 = @c_parm10  
  
         IF @b_debug='2'  
         BEGIN  
            SELECT @c_parm09 '@c_parm09',FLOOR(CAST(@c_parm09 AS FLOAT)),CEILING(CAST(@c_parm09 AS FLOAT))  
         END  
       
         SELECT @n_ttlctn = SUM(pd.qty/nullif(p.CaseCnt,0))  
         FROM MBOL MB WITH (NOLOCK)  
         JOIN ORDERS OH (NOLOCK) ON OH.MBOLKey = MB.MbolKey  
         JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey=OH.OrderKey  
         LEFT JOIN RouteMaster AS RM (NOLOCK) ON RM.[Route]=OH.[Route]  
         JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.OrderKey= OD.OrderKey   
                 AND PD.OrderLineNumber=OD.OrderLineNumber  
                 AND PD.Sku=OD.Sku    
         JOIN SKU S WITH (NOLOCK) ON PD.Storerkey=s.StorerKey AND PD.Sku = S.sku      
         JOIN PACK P WITH (NOLOCK) ON P.PackKey=S.PACKKey                      
         WHERE MB.MbolKey = @c_parm01  
         AND OH.OrderKey= @c_parm03  
        -- AND pd.ID=@c_parm10  
           
         SET @n_CtnSKU = 1  
           
         SELECT @n_CtnSKU = COUNT(1)  
         FROM MBOL MB WITH (NOLOCK)  
         JOIN ORDERS OH (NOLOCK) ON OH.MBOLKey = MB.MbolKey  
         JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey=OH.OrderKey  
         LEFT JOIN RouteMaster AS RM (NOLOCK) ON RM.[Route]=OH.[Route]  
         JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.OrderKey= OD.OrderKey   
                 AND PD.OrderLineNumber=OD.OrderLineNumber  
                 AND PD.Sku=OD.Sku    
         JOIN SKU S WITH (NOLOCK) ON PD.Storerkey=s.StorerKey AND PD.Sku = S.sku      
         JOIN PACK P WITH (NOLOCK) ON P.PackKey=S.PACKKey                      
         WHERE MB.MbolKey = @c_parm01  
         AND pd.sku = @c_parm02  
         AND pd.OrderKey= @c_parm03  
           
         --SELECT @c_parm02 '@c_parm02',@n_CtnSKU '@n_CtnSKU'  
           
        -- IF @n_CtnSKU = 1  
        -- BEGIN  
           
         SELECT @n_lineCtn = sum(pd.qty/nullif(p.CaseCnt,0))  
         ,@n_FQty = FLOOR(sum(pd.qty/nullif(p.CaseCnt,0)))  
         ,@n_CQty = CEILING(sum(pd.qty/nullif(p.CaseCnt,0)))  
         ,@c_uom = max(pd.uom)  
         --,@n_PLTQty = FLOOR(sum(pd.qty/p.pallet))  
         --,@n_CPLTQty = CEILING(sum(pd.qty/p.pallet))  
         FROM MBOL MB WITH (NOLOCK)  
         JOIN ORDERS OH (NOLOCK) ON OH.MBOLKey = MB.MbolKey  
         JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey=OH.OrderKey  
         LEFT JOIN RouteMaster AS RM (NOLOCK) ON RM.[Route]=OH.[Route]  
         JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.OrderKey= OD.OrderKey   
                 AND PD.OrderLineNumber=OD.OrderLineNumber  
                 AND PD.Sku=OD.Sku    
         JOIN PACK P WITH (NOLOCK) ON p.PackKey=pd.PackKey           
         JOIN SKU S WITH (NOLOCK) ON PD.Storerkey=s.StorerKey AND PD.Sku = S.sku                        
         WHERE MB.MbolKey = @c_parm01  
         AND pd.sku = @c_parm02  
         AND pd.OrderKey= @c_parm03  
         AND pd.ID=@c_parm10  
          
        --END   
        --ELSE  
        --BEGIN  
        -- SET @c_uom = '8'  
        --END   
           
         IF @b_debug='1'  
         BEGIN  
          SELECT  @n_lineCtn '@n_lineCtn',@n_FQty '@n_FQty',@n_CQty '@n_CQty',@c_uom '@c_uom'              
         END  
        IF @c_uom = '6'  
        BEGIN   
         IF @n_FQty <> @n_CQty -- @n_CtnSKU > 1  
         BEGIN            
          SET @c_FullCtn = 'N'  
          SET @n_ttlctn = 1  
          SET @n_lineCtn = 1             
         END  
         ELSE  
         BEGIN  
          SET @c_FullCtn = 'Y'             
         END   
          END   
          ELSE IF @c_uom IN ('1','2')  
          BEGIN  
              SET @c_FullCtn = 'Y'  
          END    
          ELSE  
          BEGIN  
             SET @c_FullCtn = 'N'  
          END   
          --SET @n_PLTQty = 0  
          --SET @n_CPLTQty = 0  
            
         IF @n_PLTQty = @n_CPLTQty  
         BEGIN  
             SET @c_Fullpallet = 'Y'  
         END   
           
         IF @b_debug='2'  
         BEGIN  
           SELECT @c_FullCtn '@c_FullCtn',@c_presku '@c_presku', @c_parm02 '@c_parm02',@n_CntRec '@n_CntRec'  
                 ,@n_lineCtn '@n_lineCtn',@n_LineStart '@n_LineStart',@n_ttlctn '@n_ttlctn',@c_uom '@c_uom'  
                 ,@c_Fullpallet '@c_Fullpallet',@n_PLTQty '@n_PLTQty',@n_CPLTQty '@n_CPLTQty',@c_parm10 '@c_parm10'  
         END    
           
         --WHILE  @n_LineStart <=@n_ttlctn  
         --BEGIN   
           
        WHILE @n_lineCtn >= 1  
        BEGIN  
         IF @c_FullCtn ='Y'  
         BEGIN   
          IF @n_CntRec = 1  
          BEGIN  
           UPDATE #TEMPRESULT  
           SET PARM04 = CAST(@n_LineStart AS NVARCHAR(5))  
             ,PARM05 = CAST(@n_ttlctn AS NVARCHAR(5))  
             ,PARM06 = @c_FullCtn  
             ,PARM07 = @c_uom  
             ,PARM08 = @c_Fullpallet  
           WHERE  PARM01=@c_parm01  
            AND PARM02=@c_parm02  
            AND PARM03=@c_parm03     
            AND parm10 = @c_parm10  
              
            --SET @n_CntRec = 0  
             
          END  
          ELSE --IF @c_uom IN ('1','2')  
          BEGIN   
            INSERT INTO #TEMPRESULT  
            (  
             PARM01,  
             PARM02,  
             PARM03,  
             PARM04,  
             PARM05,  
             PARM06,  
             PARM07,  
             PARM08,  
             PARM09,  
             PARM10,  
             Key01,  
             Key02,  
             Key03,  
             Key04,  
             Key05  
            )  
            SELECT TOP 1 PARM01,  
             PARM02,  
             PARM03,  
             CAST(@n_LineStart AS NVARCHAR(5)),  
             CAST(@n_ttlctn AS NVARCHAR(5)),  
             PARM06,  
             PARM07,  
             PARM08,  
             PARM09,  
             PARM10,  
             Key01,  
             Key02,  
             Key03,  
             Key04,  
             Key05  
            FROM #TEMPRESULT AS t  
            WHERE t.PARM01=@c_parm01  
            AND t.PARM02=@c_parm02  
            AND t.PARM03=@c_parm03  
            AND t.parm10 = @c_parm10  
          END  
         END  
         ELSE  
         BEGIN  
          UPDATE #TEMPRESULT  
           SET PARM06 = @c_FullCtn  
              ,PARM07 = @c_uom  
              ,PARM08 = @c_Fullpallet  
           WHERE  PARM01=@c_parm01  
            AND PARM02=@c_parm02  
            AND PARM03=@c_parm03     
            
         END   
          IF @b_debug='1'       
          BEGIN  
           SELECT * FROM #TEMPRESULT  
          END  
  
          --IF @n_linestart = @n_ttlctn  
          --BEGIN  
             
          -- SET @n_linestart = 1  
  
          --END  
   
          --IF @c_parm03 <> @c_preorderkey  
          --BEGIN  
           SET @n_CntRec = @n_CntRec + 1  
           --SET @n_lineCtn = @n_lineCtn - 1  
           SET @n_LineStart = @n_LineStart + 1  
           --END  
           --ELSE  
           --BEGIN  
           --   SET @n_CntRec = 1  
           ----SET @n_lineCtn =  1  
           --SET @n_LineStart = 1  
           --END   
           SET @c_preorderkey = @c_parm03  
           SET @n_lineCtn = @n_lineCtn - 1  
        END  
       --END     
      -- END    
       -- END   
                
     FETCH NEXT FROM CUR_RESULT INTO @c_parm01,@c_parm02,@c_parm03 ,@c_parm09,@c_parm10  
     END  
             
    END    
    ELSE  
    BEGIN            
      
     SET @c_refno = ''  
     IF EXISTS (SELECT 1 FROM PACKHEADER PH (nolock)  
          JOIN #TEMPRESULT TP ON TP.Parm01 = PH.Pickslipno)  
     BEGIN  
      SET @c_refno = 'Y'  
     END  
  
     IF @b_debug='5'  
     BEGIN  
       SELECT  'Print by PACK',@c_refno '@c_refno'     
     END  
  
      IF @c_refno = 'Y'  
      BEGIN  
  
           IF @b_debug='5'  
           BEGIN  
            SELECT  * FROM #TEMPRESULT  
           END  
            
       DECLARE CUR_PACK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
       SELECT DISTINCT Parm01,PARM02,parm03    
       FROM  #TEMPRESULT   
       WHERE PARM01 = @parm01  
       AND PARM04='' AND PARM05=''  
       ORDER BY  Parm01,PARM02,parm03     
    
       OPEN CUR_PACK     
     
       FETCH NEXT FROM CUR_PACK INTO @c_parm01,@c_parm02,@c_parm03   
     
       WHILE @@FETCH_STATUS <> -1    
       BEGIN     
     
     
           SET @n_ttlctn = 1  
           SET @n_Cartonno = 1  
           SET @n_Skuctn  = 1  
           SET @n_lineCtn = 1  
           SET @n_ctnrec = 0  
           --SET @c_presku = @c_parm02  
           SET @n_PLTQty = 0  
           SET @n_CPLTQty = 0  
           SET @c_Fullpallet = 'N'  
           
           SELECT @n_CntRec = COUNT(1)  
           FROM #TEMPRESULT AS t  
           WHERE t.PARM01 = @c_parm01  
           AND t.PARM02 = @c_parm02  
           AND t.PARM03= @c_parm03  
  
       
           SELECT @n_ttlctn = SUM(pd.qty/p.CaseCnt)  
                 ,@n_lineCtn = sum(pd.qty/p.CaseCnt)  
                 ,@n_FQty = FLOOR(sum(pd.qty/p.CaseCnt))  
                 ,@n_CQty = CEILING(sum(pd.qty/p.CaseCnt))  
                 ,@c_uom = max(pd.uom)  
                 ,@c_PDID = max(PD.ID)  
           FROM PACKHEADER PH WITH (nolock)  
           JOIN PACKDETAIL PAD WITH (NOLOCK) ON PH.pickslipno = PAD.pickslipno  
           JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.PickDetailKey= PAD.refno    
           JOIN SKU S WITH (NOLOCK) ON PD.Storerkey=s.StorerKey AND PD.Sku = S.sku      
           JOIN PACK P WITH (NOLOCK) ON P.PackKey=S.PACKKey                  
           WHERE PH.pickslipno = @c_parm01  
           AND PAD.cartonno= CAST(@c_parm02 as INT)  
          -- AND pd.ID=@c_parm10  
           
           --SELECT @c_parm02 '@c_parm02',@n_CtnSKU '@n_CtnSKU'  
           
          -- IF @n_CtnSKU = 1  
          -- BEGIN  
        
           IF @b_debug='5'  
           BEGIN  
            SELECT  @n_lineCtn '@n_lineCtn',@n_FQty '@n_FQty',@n_CQty '@n_CQty',@c_uom '@c_uom',@c_PDID '@c_PDID'  
           END  
  
          IF @c_uom = '6'  
          BEGIN   
           IF @n_FQty <> @n_CQty -- @n_CtnSKU > 1  
           BEGIN  
            
            SET @c_FullCtn = 'N'  
            SET @n_ttlctn = 1  
            SET @n_lineCtn = 1  
            
           END  
           ELSE  
           BEGIN  
            SET @c_FullCtn = 'Y'  
            
           END   
          END   
          ELSE IF @c_uom IN ('1','2')  
            BEGIN  
           SET @c_FullCtn = 'Y'  
            END    
            ELSE  
            BEGIN  
           SET @c_FullCtn = 'N'  
            END   
             
            
           IF @n_PLTQty = @n_CPLTQty  
           BEGIN  
           SET @c_Fullpallet = 'Y'  
           END   
           
           IF @b_debug='5'  
           BEGIN  
             SELECT @c_FullCtn '@c_FullCtn',@c_presku '@c_presku', @c_parm02 '@c_parm02',@n_CntRec '@n_CntRec'  
             ,@n_lineCtn '@n_lineCtn',@n_LineStart '@n_LineStart',@n_ttlctn '@n_ttlctn',@c_uom '@c_uom'  
             ,@c_Fullpallet '@c_Fullpallet',@n_PLTQty '@n_PLTQty',@n_CPLTQty '@n_CPLTQty',@c_parm10 '@c_parm10'  
           END    
           
            --IF @n_linestart = @n_ttlctn  
            --BEGIN  
             
            -- SET @n_linestart = 1  
  
            --END  
                        
          --END  
  
          print 'check' + 'ttlctn' + cast(@n_ttlctn as nvarchar(5))  
  
          UPDATE #TEMPRESULT  
          SET PARM04 = ISNULL(@n_ttlctn,'0')  
             ,PARM05 = @c_FullCtn  
             ,PARM07 = @c_Fullpallet  
             ,PARM08 = ISNULL(@c_uom,'6')  
             ,PARM10 = ISNULL(@c_PDID,'')  
             WHERE  PARM01=@c_parm01  
              AND PARM02=@c_parm02  
              AND PARM03=@c_parm03     
             
            IF @b_debug='5'  
            
            BEGIN  
             SELECT 'after',* FROM #TEMPRESULT  
            END  
  
            SET @n_CntRec = @n_CntRec + 1  
            SET @n_lineCtn = @n_lineCtn - 1  
            SET @n_LineStart = @n_LineStart + 1  
         --END     
        -- END    
         -- END  
       
       FETCH NEXT FROM CUR_PACK INTO @c_parm01,@c_parm02,@c_parm03   
       END  
      END    
      END       
  
    IF @b_debug='5'  
    BEGIN  
     --SELECT * FROM #TEMPRESULT AS t  
  
     SELECT DISTINCT Parm01,PARM02,parm03,parm10  
        ,rowno=ROW_NUMBER() OVER (PARTITION BY PARM10 order by PARM10)   
     FROM  #TEMPRESULT   
     ORDER BY Parm01,PARM02,parm03,parm10  
    END  
      
  IF @c_PrintMbol='Y'  
  BEGIN   
     
    SET @c_parm06 = ''  
    SET @c_parm08 = ''  
  
    SELECT DISTINCT @c_parm06 = PARM06  
        , @c_parm08 = PARM08  
   FROM #TEMPRESULT  
     
     
   IF   @c_parm06 = 'Y' and @c_parm08 = 'Y'  
   BEGIN  
     
     
    DECLARE CUR_Rownum CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
     SELECT DISTINCT Parm01,PARM02,parm03,CAST(parm04 AS INT),parm10  
           ,rowno=ROW_NUMBER() OVER (PARTITION BY PARM02,PARM10 order by CAST(parm04 as INT),PARM10)   
           ,OrderRow = ROW_NUMBER() OVER (PARTITION BY PARM03 order by CAST(parm04 as INT))   
     FROM  #TEMPRESULT   
     where CAST(parm04 AS INT) >0  
     ORDER BY CAST(parm04 as INT)  
    
     OPEN CUR_Rownum     
     
     FETCH NEXT FROM CUR_Rownum INTO @c_parm01,@c_parm02,@c_parm03,@n_parm04 ,@c_parm10,@n_rowno,@n_OrderRow   
     
     WHILE @@FETCH_STATUS <> -1    
     BEGIN  
  
     IF @b_debug='99'  
     BEGIN  
  
     SELECT DISTINCT Parm01,PARM02,parm03,CAST(parm04 AS INT),parm10  
           ,rowno=ROW_NUMBER() OVER (PARTITION BY PARM02,PARM10 order by CAST(parm04 as INT),PARM10)   
           ,OrderRow = ROW_NUMBER() OVER (PARTITION BY PARM03 order by CAST(parm04 as INT))   
     FROM  #TEMPRESULT   
     where CAST(parm04 AS INT) >0  
     ORDER BY CAST(parm04 as INT)  
  
     END  
  
     SET @c_PickslipExist = 'N'  
  
     IF EXISTS (SELECT 1 FROM PACKHEADER PH WITH (NOLOCK)  
                WHERE PH.orderkey = @c_parm03)  
     BEGIN  
         
       SET @c_PickslipExist = 'Y'  
  
     END  
  
      UPDATE #TEMPRESULT  
      SET PARM07 = convert( nvarchar(10),@n_rowno)  
         ,PARM04 = CAST(@n_OrderRow as nvarchar(10))  
         ,key01 = CASE WHEN @c_PrintMbol <> 'Y' AND @c_PickslipExist = 'Y' THEN 'Pickslipno' ELSE key01 END  
      where Parm01 = @c_parm01  
      and parm02 = @c_parm02  
      and parm03 = @c_parm03  
      and parm04  = CAST(@n_parm04 as nvarchar(10))  
      and parm10 = @c_parm10  
  
     FETCH NEXT FROM CUR_Rownum INTO @c_parm01,@c_parm02,@c_parm03,@n_parm04 ,@c_parm10,@n_rowno,@n_OrderRow   
     END   
  
    END  
          
    IF ISNULL(@parm02,'') <> '' AND ISNULL(@parm03,'') <> ''  
    BEGIN   
     IF @c_printbyOrder = 'N'  
     BEGIN    
        SELECT * FROM #TEMPRESULT       
         WHERE PARM06='Y'  
         and PARM07 between @parm02 and @parm03  
         ORDER BY PARM01, PARM02, PARM03, CAST(PARM04 AS INT)    
     END  
     ELSE  
     BEGIN  
        SELECT * FROM #TEMPRESULT       
         WHERE PARM06='Y'  
         and PARM04 between @parm02 and @parm03  
         ORDER BY PARM01, PARM02, PARM03, CAST(PARM04 AS INT)  
     END  
            END  
   ELSE  
   BEGIN  
     SELECT * FROM #TEMPRESULT       
     WHERE PARM06='Y'  
     ORDER BY PARM01, PARM02, PARM03, CAST(PARM04 AS INT)   
  
   END  
  END  
  ELSE   
  BEGIN  
     
    DECLARE CUR_Rownum CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
     SELECT DISTINCT Parm01,CAST(parm02 AS INT),parm03,parm10  
        ,rowno=ROW_NUMBER() OVER (PARTITION BY PARM10 order by CAST(parm02 as INT),PARM10)   
     FROM  #TEMPRESULT   
     ORDER BY CAST(parm02 as INT)  
    
     OPEN CUR_Rownum     
     
     FETCH NEXT FROM CUR_Rownum INTO @c_parm01,@n_parm02,@c_parm03,@c_parm10,@n_rowno   
     
     WHILE @@FETCH_STATUS <> -1    
     BEGIN  
  
     SET @c_PickslipExist = 'N'  
  
     IF EXISTS (SELECT 1 FROM PACKHEADER PH WITH (NOLOCK)  
                WHERE PH.orderkey = @c_parm03)  
     BEGIN  
         
       SET @c_PickslipExist = 'Y'  
  
     END  
       
  
      UPDATE #TEMPRESULT  
      SET PARM07 = convert( nvarchar(10),@n_rowno)  
       ,key01 = CASE WHEN @c_PrintMbol <> 'Y' AND @c_PickslipExist = 'Y' THEN 'Pickslipno' ELSE key01 END  
      where Parm01 = @c_parm01  
      and parm02 =CAST(@n_parm02 as nvarchar(10))  
      and parm03 = @c_parm03  
      and parm10 = @c_parm10  
  
     FETCH NEXT FROM CUR_Rownum INTO @c_parm01,@n_parm02,@c_parm03,@c_parm10,@n_rowno  
     END   
       
     SELECT * FROM #TEMPRESULT       
     ORDER BY PARM01, PARM03, CAST(PARM02 AS INT)    
              
  END   
      
     
    
 EXIT_SP:      
    
  SET @d_Trace_EndTime = GETDATE()    
  SET @c_UserName = SUSER_SNAME()    
  
              
 END -- procedure     
  

GO
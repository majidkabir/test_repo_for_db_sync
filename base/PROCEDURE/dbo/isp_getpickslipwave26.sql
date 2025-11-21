SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/        
/* Stored Proc: isp_GetPickSlipWave26                                   */        
/* Creation Date: 07-SEP-2020                                           */      
/* Copyright: LF Logistics                                              */      
/* Written by: CSCHONG                                                  */      
/*                                                                      */      
/* Purpose: WMS-14891 - KR_ADIDAS_Picking Slip Report Data Window_NEW   */      
/*        :                                                             */      
/* Called By: R_dw_print_wave_pickslip_26                               */      
/*          :                                                           */       
/* PVCS Version: 1.3                                                    */        
/*                                                                      */        
/* Version: 7.0                                                         */        
/*                                                                      */        
/* Data Modifications:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date         Author   Ver   Purposes                                 */       
/* 15-MAR-2021  CSCHONG  1.1   WMS-16525 new sub report (CS01)          */    
/* 25-May-2021  BeeTin   1.2   INC1482698-filter by doctype<>'e' for    */  
/*                             avoid pickslip duplicate print           */  
/* 28-Dec-2021  WLChooi  1.3   DevOps Combine Script                    */
/* 28-Dec-2021  WLChooi  1.3   WMS-18409 Extend @cValue length (WL01)   */
/************************************************************************/        
CREATE PROC [dbo].[isp_GetPickSlipWave26]      
           @c_wavekey_type       NVARCHAR(15)        
      
AS        
BEGIN        
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
        
   DECLARE          
           @n_StartTCnt       INT        
         , @n_Continue        INT        
         , @b_Success         INT        
         , @n_Err             INT        
         , @c_ErrMsg          NVARCHAR(255)         
        
         , @c_Wavekey         NVARCHAR(10)        
         , @c_Type            NCHAR(5)        
        
         , @n_WaveSeqOfDay    INT        
         , @dt_Adddate        DATETIME        
         , @d_Adddate         DATETIME        
        
         , @n_RowNum          INT        
         , @c_PickSlipNo      NVARCHAR(10)        
         , @c_PickHeaderKey   NVARCHAR(10)        
         , @c_PickSlipNo_PD   NVARCHAR(10)        
         , @c_Zone            NVARCHAR(10)        
          
         , @c_PickDetailKey   NVARCHAR(10)        
         , @c_Orderkey        NVARCHAR(10)        
         , @c_Loadkey         NVARCHAR(10)        
         , @c_OrderLineNumber NVARCHAR(5)        
                 
         , @CUR_PSLIP         CURSOR        
         , @CUR_PD            CURSOR        
         , @CUR_PACKSLIP      CURSOR        
      
      
         , @c_wavetype             NVARCHAR(36) = ''        
         , @c_OrderSelectionKey    NVARCHAR(20) = ''        
         , @c_ColorCode            NVARCHAR(30) = ''        
               
         ,@bInValid                BIT,        
          @cTableName              NVARCHAR(30),       
          @cValue                  NVARCHAR(4000),   --WL01        
          @cColumnName             NVARCHAR(250),        
          @cCondLevel              NVARCHAR(10),        
          @cColName                NVARCHAR(128),        
          @cColType                NVARCHAR(128),        
          @cOrAnd                  NVARCHAR(10),        
          @cOperator               NVARCHAR(10),        
          @nTotalOrders            INT,        
          @nTotalOpenQty           INT,          
          @nPreCondLevel           INT,        
          @nCurrCondLevel          INT,      
          @noOfOrdKey              INT,      
          @noOfOrdKeyTmp           INT,      
          @c_tmpOrderSelectionKey  NVARCHAR(10) = '',      
          @c_orderSelectionKey2    NVARCHAR(10) = '',      
          @c_tmpCondNo             NVARCHAR(10) = ''      
               
         , @nMaxOrders             INT        
         , @nMaxOpenQty            INT      
         , @cGroupBy               NVARCHAR (2000)      
         , @cSQL                   NVARCHAR(MAX)      
         , @cSQL2                  NVARCHAR(MAX)      
         , @c_OrdDocType           NVARCHAR(5)            --CS01      
         , @n_cntOrdtype           INT                    --CS01      
      
   CREATE TABLE #TEMPORDKEY(      
      orderkey             NVARCHAR(10)      
     ,OrdDocType           NVARCHAR(5)           --CS01      
      )      
      
      CREATE TABLE #TMPOSK(      
      OrderSelectionKey NVARCHAR(40)      
      )      
                
   SET @cGroupBy  = N' GROUP BY        
                    ORDERS.OrderKey        
                   ,isnull(ORDERS.DocType,'''')      
                   ,ORDERS.ExternOrderkey        
                   ,ORDERS.OpenQty'        
        
   SET @n_StartTCnt = @@TRANCOUNT        
   SET @n_Continue = 1        
        
          
        
   SET @n_StartTCnt = @@TRANCOUNT        
   SET @n_Continue = 1        
   SET @n_err      = 0        
   SET @c_errmsg   = ''        
        
   CREATE TABLE #TMP_PSLIP        
      (        
         RowNum            INT   IDENTITY(1,1)  NOT NULL PRIMARY KEY        
      ,  Storerkey         NVARCHAR(15)   NULL        
      ,  Wavekey           NVARCHAR(10)   NULL        
      ,  PickHeaderKey     NVARCHAR(10)   NULL        
      ,  PutawayZone       NVARCHAR(10)   NULL        
      ,  Printedflag       NCHAR(1)       NULL        
      ,  NoOfSku           INT            NULL        
      ,  NoOfPickLines     INT            NULL      
      ,  OrdSelectkey      NVARCHAR(20)   NULL      
      ,  ColorCode         NVARCHAR(20)   NULL        
      ,  ORDDoctype        NVARCHAR(10)   NULL    --CS01      
      )        
        
          
   SET @c_Wavekey = SUBSTRING(@c_wavekey_type, 1, 10)          
   SET @c_Type    = SUBSTRING(@c_wavekey_type, 11,2)          
         
        
   SELECT TOP 1 @c_WaveType = RTRIM(WaveType )      
   FROM WAVE (NOLOCK) WHERE WAVEKEY = @C_WAVEKEY      
         
   SELECT @noOfOrdKey = COUNT(ORDERKEY) FROM WAVEDETAIL (NOLOCK)      
   WHERE WAVEDETAIL.WAVEKEY = @C_WAVEKEY      
      
   CREATE TABLE #TEMPOSK(      
   OrderSelectionKey NVARCHAR(40)      
   ,NoOfCond INT NULL               
   )      
   INSERT INTO #TEMPOSK(ORDERSELECTIONKEY)      
   SELECT DISTINCT OrderSelection.OrderSelectionKey      
            FROM ORDERS WITH (NOLOCK)        
      JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)        
      JOIN OrderSelection WITH (NOLOCK) ON  (ORDERS.Storerkey >= OrderSelection.storerkeystart)        
                         AND (ORDERS.Storerkey <= OrderSelection.storerkeyend)        
                         AND (ORDERS.OrderDate >= OrderSelection.orderdatestart)        
                         AND (ORDERS.OrderDate <= OrderSelection.orderdateend)        
      JOIN WAVEDETAIL (NOLOCK) ON (ORDERS.ORDERKEY = WAVEDETAIL.ORDERKEY)      
      JOIN ORDERSELECTIONCONDITION (NOLOCK) ON (ORDERSELECTIONCONDITION.ORDERSELECTIONKEY = ORDERSELECTION.ORDERSELECTIONKEY)      
      LEFT JOIN V_StorerConfig2 SC WITH (NOLOCK) ON ORDERS.Storerkey = SC.Storerkey AND SC.Configkey = 'WaveSkipUserdefine08Chk'      
      LEFT JOIN ORDERINFO WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERINFO.Orderkey)        
      JOIN WAVE (NOLOCK) ON WAVE.WaveKey = WAVEDETAIL.WaveKey --CS01              
      WHERE (ORDERS.UserDefine08 = 'Y' OR ISNULL(SC.Svalue,'')='1')        
       AND (NOT ORDERS.Status IN ('8', '9') )        
       AND (ORDERS.ConsigneeKey >= OrderSelection.consigneekeystart)        
       AND (ORDERS.ConsigneeKey <=  OrderSelection.consigneekeyend)        
       AND (ORDERS.Type >=  OrderSelection.ordertypestart)        
       AND (ORDERS.Type <=  OrderSelection.OrderTypeEnd)        
       AND (ORDERS.DeliveryDate >= OrderSelection.deliveryDateStart)        
       AND (ORDERS.DeliveryDate <= OrderSelection.deliveryDateEnd)        
       AND (ORDERS.Priority >= OrderSelection.orderpriorityStart)        
       AND (ORDERS.Priority <= OrderSelection.orderpriorityEnd)        
       AND (ORDERS.Intermodalvehicle >= OrderSelection.carrierkeystart)        
       AND (ORDERS.Intermodalvehicle <= OrderSelection.carrierkeyend)        
       AND (ORDERS.Orderkey >= OrderSelection.OrderkeyStart)        
       AND (ORDERS.Orderkey <= OrderSelection.OrderkeyEnd)        
       AND (ORDERS.ExternOrderkey >= OrderSelection.ExternOrderkeyStart)        
       AND (ORDERS.ExternOrderkey <= OrderSelection.ExternOrderkeyEnd)        
       AND (ORDERS.Route >= OrderSelection.RouteStart)        
       AND (ORDERS.Route <= OrderSelection.RouteEnd)        
       AND (ORDERS.Door >= OrderSelection.DoorStart)        
       AND (ORDERS.Door <= OrderSelection.DoorEnd)        
       AND (ORDERS.Stop >= OrderSelection.StopStart)        
       AND (ORDERS.Stop <= OrderSelection.StopEnd)        
       AND (ORDERS.OrderGroup >= OrderSelection.ordergroupstart)        
       AND (ORDERS.OrderGroup <= OrderSelection.ordergroupEnd)        
       AND (ISNULL(ORDERS.BuyerPO,'') >= OrderSelection.BuyerPOStart)        
       AND (ISNULL(ORDERS.BuyerPO,'') <= OrderSelection.BuyerPOEnd)        
       --AND (ORDERS.UserDefine09 IS NULL OR ORDERS.UserDefine09 = '')  --This is wavekey      
       AND (ORDERS.SOStatus <> 'PENDING')        
       AND (ORDERS.SOStatus NOT IN (SELECT CODELKUP.Code        
                             FROM CODELKUP WITH (NOLOCK)        
                             WHERE CODELKUP.Listname = 'WBEXCSOSTS'        
                             AND CODELKUP.Storerkey = ORDERS.Storerkey))        
       AND (ISNULL(ORDERS.Doctype,'') >= OrderSelection.DocTypeStart)        
       AND (ISNULL(ORDERS.Doctype,'') <= OrderSelection.DocTypeEnd)        
       AND (ISNULL(ORDERS.BillToKey,'') >= OrderSelection.BillToKeyStart)        
       AND (ISNULL(ORDERS.BillToKey,'') <= OrderSelection.BillToKeyEnd)        
       AND (ISNULL(ORDERS.M_ISOCntryCode,'') >= OrderSelection.M_ISOCntryCodeStart)        
       AND (ISNULL(ORDERS.M_ISOCntryCode,'') <= OrderSelection.M_ISOCntryCodeEnd)        
       AND (ISNULL(ORDERS.UserDefine05,'') >= OrderSelection.UserDefine05Start)        
       AND (ISNULL(ORDERS.UserDefine05,'') <= OrderSelection.UserDefine05End)        
       AND (ISNULL(ORDERS.SpecialHandling,'') >= OrderSelection.SpecialHandlingStart)        
       AND (ISNULL(ORDERS.SpecialHandling,'') <= OrderSelection.SpecialHandlingEnd)        
       AND (ISNULL(ORDERS.DeliveryNote,'') >= OrderSelection.DeliveryNoteStart)        
       AND (ISNULL(ORDERS.DeliveryNote,'') <= OrderSelection.DeliveryNoteEnd)      
       AND (ORDERS.Facility = CASE WHEN ISNULL(OrderSelection.Facility, '') <> ''       
       THEN OrderSelection.Facility ELSE ORDERS.Facility END)          
       AND WAVEDETAIL.WAVEKEY = @c_wavekey       
      
    DECLARE CUR_NOOFCOND CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
    SELECT DISTINCT ORDERSELECTIONKEY FROM #TEMPOSK WHERE  ORDERSELECTIONKEY =@c_wavetype      
    OPEN CUR_NOOFCOND      
    FETCH NEXT FROM CUR_NOOFCOND INTO @c_tmpOrderSelectionKey      
    WHILE @@FETCH_STATUS <> -1       
    BEGIN      
      
    SELECT @c_tmpCondNo =  COUNT(Orderselectioncondition.OrderSelectionLineNumber)      
    FROM ORDERSELECTIONCONDITION (NOLOCK)      
    WHERE ORDERSELECTIONCONDITION.ORDERSELECTIONKEY = @c_tmpOrderSelectionKey      
    AND ORDERSELECTIONCONDITION.TYPE = 'CONDITION'      
      
    UPDATE #TEMPOSK       
    SET NoOfCond = @c_tmpCondNo      
    WHERE ORDERSELECTIONKEY = @c_tmpOrderSelectionKey      
    SET @c_tmpCondNo = ''      
    FETCH NEXT FROM CUR_NOOFCOND INTO @c_tmpOrderSelectionKey      
    END      
      
    DECLARE CUR_OSK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
    SELECT  ORDERSELECTIONKEY FROM #TEMPOSK WHERE ORDERSELECTIONKEY = @c_wavetype     --CS01a      
    ORDER BY NoOfCond DESC      
    OPEN CUR_OSK      
    FETCH NEXT FROM CUR_OSK INTO @c_tmpOrderSelectionKey      
    WHILE @@FETCH_STATUS <> -1       
    BEGIN      
      
    DECLARE CUR_BUILD_WAVE_COND CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
       SELECT FieldName, ISNULL([Value],''), ConditionGroup, OperatorAndOr, Operator        
       FROM   OrderSelectionCondition WITH (NOLOCK)        
       WHERE  OrderSelectionKey = @c_tmpOrderSelectionKey        
       AND    [Type] = 'CONDITION'        
       ORDER BY OrderSelectionLineNumber       
            
      
      OPEN CUR_BUILD_WAVE_COND        
      FETCH NEXT FROM CUR_BUILD_WAVE_COND INTO @cColumnName, @cValue, @cCondLevel, @cOrAnd, @cOperator        
        
      WHILE @@FETCH_STATUS <> -1        
      BEGIN      
       
         IF ISNUMERIC(@cCondLevel) = 1        
         BEGIN        
           IF @nPreCondLevel=0        
             SET @nPreCondLevel = CAST(@cCondLevel AS INT)        
           SET @nCurrCondLevel = CAST(@cCondLevel AS INT)        
         END        
        
         SET @cTableName = LEFT(@cColumnName, CHARINDEX('.', @cColumnName) - 1)        
         SET @cColName   = SUBSTRING(@cColumnName, CHARINDEX('.', @cColumnName) + 1, LEN(@cColumnName) - CHARINDEX('.', @cColumnName))        
        
         SET @cColType = ''        
         SELECT @cColType = DATA_TYPE        
         FROM   INFORMATION_SCHEMA.COLUMNS        
         WHERE  TABLE_NAME = @cTableName        
         AND    COLUMN_NAME = @cColName        
        
         IF ISNULL(RTRIM(@cColType), '') = ''        
         BEGIN        
           SET @bInValid = 1        
          -- SET @cErrorMsg = 'Invalid Column Name: ' + @cColumnName        
          -- GOTO QUIT        
         END        
        
         IF @cColType = 'DATETIME' AND        
           ISDATE(@cValue) <> 1        
         BEGIN        
           IF @cValue IN ('today','now', 'startofmonth', 'endofmonth', 'startofyear', 'endofyear')        
           BEGIN        
             SET @cValue = CASE @cValue        
                           WHEN 'today'        
                             THEN LEFT(CONVERT(VARCHAR(30), GETDATE(), 120), 10)        
                           WHEN 'now'        
                             THEN CONVERT(VARCHAR(30), GETDATE(), 120)        
                           WHEN 'startofmonth'        
                             THEN CAST(DATEPART(YEAR, GETDATE()) AS VARCHAR(4)) + '-'        
                               + ('0' + CAST(DATEPART(MONTH, GETDATE()) AS VARCHAR(2))) + ('-01')        
                           WHEN 'endofmonth'        
                             THEN CONVERT(VARCHAR(30), DATEADD(s,-1,DATEADD(mm, DATEDIFF(m,0,GETDATE())+1,0)), 120)        
                           WHEN 'startofyear'        
                             THEN CAST(DATEPART(YEAR, GETDATE()) AS VARCHAR(4)) + '-01-01'        
                           WHEN 'endofyear'        
                             THEN CAST(DATEPART(YEAR, GETDATE()) AS VARCHAR(4)) + '-12-31 23:59:59'        
                        END        
           END        
           ELSE        
           BEGIN        
             SET @bInValid = 1        
            -- SET @cErrorMsg = 'Invalid Date Format: ' + @cValue        
            -- GOTO QUIT        
           END        
         END        
        
         IF @nPreCondLevel < @nCurrCondLevel        
         BEGIN        
           SET @cSQL2 = @cSQL2 + ' ' + master.dbo.fnc_GetCharASCII(13) + ' ' + @cOrAnd + N' ('        
           SET @nPreCondLevel = @nCurrCondLevel        
         END        
         ELSE IF @nPreCondLevel > @nCurrCondLevel        
         BEGIN        
           SET @cSQL2 = @cSQL2 + N') '  + master.dbo.fnc_GetCharASCII(13) + ' ' + @cOrAnd        
   SET @nPreCondLevel = @nCurrCondLevel        
         END        
         ELSE        
         BEGIN        
           SET @cSQL2 = @cSQL2 + ' ' + master.dbo.fnc_GetCharASCII(13) + ' ' + @cOrAnd        
         END        
        
         IF @cColType IN ('CHAR', 'NVARCHAR', 'VARCHAR','NCHAR') --NJOW01        
           SET @cSQL2 = @cSQL2 + ' ' + @cColumnName + ' ' + @cOperator +        
               CASE WHEN @cOperator = 'IN' THEN        
                  CASE WHEN LEFT(RTRIM(LTRIM(@cValue)),1) <> '(' THEN '(' ELSE '' END +        
                  RTRIM(LTRIM(@cValue)) +        
                  CASE WHEN RIGHT(RTRIM(LTRIM(@cValue)),1) <> ')' THEN ') ' ELSE '' END        
               ELSE ' N' +        
                  CASE WHEN LEFT(RTRIM(LTRIM(@cValue)),1) <> '''' THEN '''' ELSE '' END +        
                  RTRIM(LTRIM(@cValue)) +        
                  CASE WHEN RIGHT(RTRIM(LTRIM(@cValue)),1) <> '''' THEN ''' ' ELSE '' END        
               END        
         ELSE IF @cColType IN ('FLOAT', 'MONEY', 'INT', 'DECIMAL', 'NUMERIC', 'TINYINT', 'REAL', 'BIGINT')        
           SET @cSQL2 = @cSQL2 + ' ' + @cColumnName + ' ' + @cOperator  + RTRIM(@cValue)        
         ELSE IF @cColType IN ('DATETIME')        
           SET @cSQL2 = @cSQL2 + ' ' + @cColumnName + ' ' + @cOperator + ' '''+ @cValue + ''' '        
         FETCH NEXT FROM CUR_BUILD_WAVE_COND INTO @cColumnName, @cValue, @cCondLevel, @cOrAnd, @cOperator        
      END       
      CLOSE CUR_BUILD_WAVE_COND        
      DEALLOCATE CUR_BUILD_WAVE_COND        
      
      WHILE @nPreCondLevel > 1        
      BEGIN        
         SET @cSQL2 = @cSQL2 + N') '        
         SET @nPreCondLevel = @nPreCondLevel - 1        
      END           
            
      set @cSQL = N' INSERT INTO #TEMPORDKEY '+      
      'select DISTINCT isnull(ORDERS.orderkey,''''),isnull(ORDERS.DocType,'''') from wavedetail WITH (NOLOCK)' +      
      'JOIN ORDERS WITH (NOLOCK) ON wavedetail.ORDERKEY = ORDERS.ORDERKEY '  +        
      'JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey) '+        
      'LEFT JOIN ORDERINFO WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERINFO.Orderkey) '+        
      'where wavedetail.wavekey = ' + @c_wavekey      
      SET @cSQL2 = RTRIM(@cSQL2) + CHAR(13) + @cGroupBy      
      
      exec( @cSQL + ' ' +  @cSQL2 )      
      
      --CS01a START      
        SET @n_cntOrdtype = 1      
        SET @c_OrdDocType = ''      
      
      SELECT @n_cntOrdtype = COUNT(DISTINCT OrdDocType)      
      FROM #TEMPORDKEY      
      
      IF @n_cntOrdtype = 0       
      BEGIN      
       --SET @n_cntOrdtype = 1  --CS01a      
         SET @n_continue = 3              
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)            
         SET @n_err = 81090  -- Should Be Set To The SQL Errmessage but I don't know how to do so.              
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': wave not had doctype (isp_GetPickSlipWave26)'           
                           + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP         
      END      
      
      IF @n_cntOrdtype = 1      
      BEGIN      
      
         SELECT TOP 1 @c_OrdDocType = OrdDocType      
         FROM #TEMPORDKEY      
      
         IF ISNULL(@c_OrdDocType,'') = ''      
         BEGIN      
           --SET @c_OrdDocType = 'N'      
         SET @n_continue = 3              
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)            
         SET @n_err = 81090  -- Should Be Set To The SQL Errmessage but I don't know how to do so.              
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': wave not had doctype (isp_GetPickSlipWave26)'           
                           + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP         
         END      
      END      
      ELSE      
      BEGIN      
         SET @n_continue = 3              
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)            
         SET @n_err = 81080  -- Should Be Set To The SQL Errmessage but I don't know how to do so.              
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': wave consists more than 1 doctype (isp_GetPickSlipWave26)'           
                           + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP             
      END      
     --CS01a END      
      
      SELECT @noOfOrdKeyTmp = count(orderkey) FROM #TEMPORDKEY      
      
      IF(@noOfOrdKeyTmp = @noOfOrdKey)      
      BEGIN      
         INSERT INTO #TMPOSK(OrderSelectionKey)      
         VALUES(@c_tmpOrderSelectionKey)      
         TRUNCATE TABLE #TEMPORDKEY      
      END      
      
      TRUNCATE TABLE #TEMPORDKEY      
            
      SET @csql2 =''      
      SET @noOfOrdKeyTmp =''      
      
    FETCH NEXT FROM CUR_OSK INTO @c_tmpOrderSelectionKey      
    END      
    CLOSE CUR_OSK        
    DEALLOCATE CUR_OSK      
      
   IF NOT EXISTS (SELECT TOP 1 * FROM #TMPOSK) --Add dummy value      
   BEGIN      
   INSERT INTO #TMPOSK      
   VALUES('0')      
   END      
      
   SELECT @c_orderSelectionKey = RTRIM(OrderSelectionKey)      
   FROM #TMPOSK           
   WHERE ORDERSELECTIONKEY = RTRIM(@c_wavetype)      
      
   IF(@c_orderSelectionKey <> @c_wavetype)      
   BEGIN       
            SET @n_continue = 3              
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)            
            SET @n_err = 81070  -- Should Be Set To The SQL Errmessage but I don't know how to do so.              
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Wavetype and OrderSelectionKey Mismatch (isp_GetPickSlipWave26)'           
                           + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
            GOTO QUIT_SP             
     END          
      
   INSERT INTO #TMP_PSLIP                                                  
      (  Storerkey             
      ,  Wavekey               
      ,  PickHeaderKey           
      ,  PutawayZone         
      ,  Printedflag          
      ,  NoOfSku                
      ,  NoOfPickLines       
      ,  OrdSelectkey      
      ,  ColorCode       
      ,  ORDDoctype         --CS01            
      )                                   
   SELECT PD.Storerkey        
         ,WD.Wavekey        
         ,PickHeaderKey = CASE WHEN ISNULL(RTRIM(PH.PickHeaderkey),'') <> '' THEN ISNULL(RTRIM(PH.PickHeaderkey),'')      
                           ELSE ISNULL(RTRIM(PHORD.PickHeaderkey),'') END        
         ,LOC.PutawayZone                                                        
         ,Printedflag = CASE WHEN ISNULL(RTRIM(PH.PickHeaderkey), '') =  '' THEN 'N' ELSE 'Y' END        
         ,NoOfSku= COUNT(DISTINCT PD.Sku)        
         ,NoOfPickLines= COUNT(DISTINCT PD.PickDetailkey)      
         ,Orderselectionkey = CASE WHEN @c_orderSelectionKey = '0' THEN '' ELSE @c_orderSelectionKey END       
         ,ColorCode = ISNULL(CLR.CODE,'')   --WL01      
         ,OrdDoctype = @c_OrdDocType        --CS01      
   FROM WAVEDETAIL WD   WITH (NOLOCK)          
   JOIN PICKDETAIL PD   WITH (NOLOCK) ON (WD.Orderkey= PD.Orderkey)        
   JOIN LOC        LOC  WITH (NOLOCK) ON (PD.Loc = LOC.Loc)                     
   LEFT JOIN REFKEYLOOKUP RL WITH (NOLOCK) ON (PD.PickDetailKey = RL.PickDetailkey)        
   LEFT JOIN PICKHEADER   PH WITH (NOLOCK) ON (RL.PickSlipNo = PH.PickHeaderkey)       
   LEFT JOIN PICKHEADER   PHORD WITH (NOLOCK) ON (PD.Orderkey = PHORD.orderkey)      
   LEFT JOIN CODELKUP CLR WITH (NOLOCK) ON CLR.LISTNAME = 'OSKCOLOR' AND CLR.LONG = @c_orderSelectionKey        
   WHERE WD.Wavekey = @c_Wavekey        
   AND   PD.Status < '5'        
   GROUP BY PD.Storerkey        
         ,  WD.Wavekey        
         ,  ISNULL(RTRIM(PH.PickHeaderkey), '')        
         ,  ISNULL(RTRIM(PHORD.PickHeaderkey),'')      
         ,  LOC.PutawayZone                                                       
       , ISNULL(CLR.CODE,'')          
   ORDER BY ISNULL(RTRIM(PH.PickHeaderkey), ''),ISNULL(RTRIM(PHORD.PickHeaderkey),'')         
         ,  LOC.PutawayZone           
      
      
   SET @CUR_PSLIP = CURSOR FAST_FORWARD READ_ONLY FOR        
   SELECT   RowNum        
         ,  PickHeaderKey         
         ,  PutawayZone        
   FROM #TMP_PSLIP        
   WHERE OrdDoctype = 'E'                    --CS01      
   ORDER BY RowNum        
        
   OPEN @CUR_PSLIP        
        
   FETCH NEXT FROM @CUR_PSLIP INTO @n_RowNum, @c_PickSlipNo, @c_Zone        
        
   WHILE @@FETCH_STATUS = 0        
   BEGIN        
      IF @c_PickSlipNo = ''          
      BEGIN        
         EXECUTE nspg_GetKey               
                  'PICKSLIP'            
               ,  9            
               ,  @c_PickSlipNo  OUTPUT            
               ,  @b_Success     OUTPUT            
               ,  @n_err         OUTPUT            
               ,  @c_errmsg      OUTPUT         
                                
         IF @b_success <> 1           
         BEGIN            
            SET @n_continue = 3          
            SET @n_err = 81010        
   SET @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Get PickSlip # Failed. (isp_GetPickSlipWave26)'          
            BREAK           
         END                     
         
         SET @c_PickSlipNo = 'P' + @c_PickSlipNo                  
                              
         INSERT INTO PICKHEADER              
                  (  PickHeaderKey            
                  ,  Wavekey            
                  ,  Orderkey            
                  ,  ExternOrderkey            
                  ,  Loadkey            
                  ,  PickType            
                  ,  Zone            
                  ,  consoorderkey        
                  ,  TrafficCop            
                  )              
         VALUES              
                  (  @c_PickSlipNo            
                  ,  @c_Wavekey            
                  ,  ''        
                  ,  @c_PickSlipNo           
                  ,  ''          
                  ,  '0'             
                  ,  'LP'          
                  ,  @c_Zone          
                  ,  ''            
     )                  
                     
         SET @n_err = @@ERROR              
         IF @n_err <> 0              
         BEGIN              
            SET @n_continue = 3              
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)            
            SET @n_err = 81020  -- Should Be Set To The SQL Errmessage but I don't know how to do so.              
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (isp_GetPickSlipWave26)'           
                           + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
            GOTO QUIT_SP             
         END          
           
         UPDATE #TMP_PSLIP        
         SET PickHeaderKey = @c_PickSlipNo        
         WHERE RowNum = @n_RowNum        
         AND PickHeaderkey = ''        
      END                 
           
      SET @CUR_PD = CURSOR FAST_FORWARD READ_ONLY FOR        
      SELECT   PD.PickDetailKey           
            ,  PD.Orderkey        
            ,  PD.OrderLineNumber        
            ,  ISNULL(RTRIM(PD.PickSlipNo),'')        
      FROM WAVEDETAIL WD  WITH (NOLOCK)         
      JOIN PICKDETAIL PD  WITH (NOLOCK) ON (WD.Orderkey = PD.Orderkey)        
      JOIN LOC        LOC WITH (NOLOCK) ON (PD.Loc = LOC.Loc)                                           
      WHERE WD.Wavekey = @c_Wavekey        
      AND   LOC.PutawayZone = @c_Zone                                                  
      ORDER BY PD.PickDetailKey               
        
      OPEN @CUR_PD        
        
      FETCH NEXT FROM @CUR_PD INTO @c_PickDetailKey        
                                 , @c_Orderkey        
                                 , @c_OrderLineNumber        
                  , @c_PickSlipNo_PD        
        
      WHILE @@FETCH_STATUS = 0        
      BEGIN        
         IF NOT EXISTS (SELECT 1         
                        FROM REFKEYLOOKUP RL WITH (NOLOCK)         
                        WHERE PickDetailKey = @c_PickDetailKey)        
         BEGIN        
            INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber )          
            VALUES (@c_PickDetailKey, @c_PickSlipNo, @c_OrderKey, @c_OrderLineNumber)        
        
            SET @n_err = @@ERROR          
            IF @n_err <> 0           
            BEGIN          
               SET @n_continue = 3        
               SET @n_err = 81030        
               SET @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RefKeyLookup Failed. (isp_GetPickSlipWave26)'            
               GOTO QUIT_SP        
            END                        
         END        
        
         IF @c_PickSlipNo <> @c_PickSlipNo_PD        
         BEGIN        
            UPDATE PICKDETAIL WITH (ROWLOCK)        
            SET PickSlipNo = @c_PickSlipNo        
               ,EditWho    = SUSER_NAME()        
               ,EditDate   = GETDATE()        
               ,Trafficcop = NULL        
            WHERE PickDetailkey = @c_PickDetailKey        
        
            SET @n_err = @@ERROR              
            IF @n_err <> 0              
            BEGIN              
               SET @n_continue = 3              
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)            
               SET @n_err = 81040 -- Should Be Set To The SQL Errmessage but I don't know how to do so.              
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE Pickdetail Failed (isp_GetPickSlipWave26)'           
                              + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
               GOTO QUIT_SP             
            END         
         END        
        
         FETCH NEXT FROM @CUR_PD INTO @c_PickDetailKey        
                                    , @c_Orderkey        
                                    , @c_OrderLineNumber        
                                    , @c_PickSlipNo_PD        
      END        
        
      CLOSE @CUR_PD        
      DEALLOCATE @CUR_PD        
        
      FETCH NEXT FROM @CUR_PSLIP INTO @n_RowNum, @c_PickSlipNo, @c_Zone        
        
   END        
   CLOSE @CUR_PSLIP        
   DEALLOCATE @CUR_PSLIP        
      
   SET @CUR_PACKSLIP = CURSOR FAST_FORWARD READ_ONLY FOR        
   SELECT OH.Orderkey           
         ,OH.LoadKey        
   FROM WAVEDETAIL WD      WITH (NOLOCK)        
   JOIN ORDERS     OH      WITH (NOLOCK) ON (WD.Orderkey = OH.Orderkey)        
   LEFT OUTER JOIN PICKHEADER PH WITH (NOLOCK) ON (OH.Orderkey = PH.Orderkey)        
                                         AND(OH.Loadkey  = PH.ExternOrderkey)        
   WHERE WD.Wavekey = @c_Wavekey         
   AND   PH.PickHeaderKey IS NULL     
     AND OH.DocType <>'E'          --INC1482698    
         
   OPEN @CUR_PACKSLIP        
        
   FETCH NEXT FROM @CUR_PACKSLIP INTO @c_Orderkey        
                                    , @c_Loadkey        
                                  
        
   WHILE @@FETCH_STATUS = 0        
   BEGIN        
      SET @c_PickSlipNo = ''        
      EXECUTE nspg_GetKey               
               'PICKSLIP'            
            ,  9            
            ,  @c_PickSlipNo  OUTPUT            
            ,  @b_Success     OUTPUT            
            ,  @n_err         OUTPUT            
            ,  @c_errmsg      OUTPUT         
                                
      IF @b_success <> 1           
      BEGIN            
         SET @n_continue = 3          
         SET @n_err = 81050        
         SET @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Get PickSlip # Failed. (isp_GetPickSlipWave26)'          
         BREAK           
      END                     
         
      SET @c_PickSlipNo = 'P' + @c_PickSlipNo                  
                              
      INSERT INTO PICKHEADER              
               (  PickHeaderKey            
               ,  Wavekey            
               ,  Orderkey            
               ,  ExternOrderkey            
               ,  Loadkey            
               ,  PickType            
               ,  Zone            
               ,  consoorderkey        
               ,  TrafficCop            
               )              
      VALUES              
               (  @c_PickSlipNo            
               ,  @c_Wavekey            
               ,  @c_Orderkey        
               ,  @c_Loadkey         
               ,  @c_Loadkey          
               ,  '0'             
               ,  '3'          
               ,  ''          
               ,  ''            
               )                  
                     
      SET @n_err = @@ERROR           
           
      IF @n_err <> 0              
      BEGIN              
         SET @n_continue = 3              
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)            
         SET @n_err = 81060  -- Should Be Set To The SQL Errmessage but I don't know how to do so.              
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (isp_GetPickSlipWave26)'           
                        + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP             
      END          
      
      UPDATE #TMP_PSLIP      
      SET PickHeaderKey = @c_PickSlipNo      
      WHERE Wavekey = @c_Wavekey      
      AND PickHeaderKey = ''      
        
      FETCH NEXT FROM @CUR_PACKSLIP INTO @c_Orderkey        
                                       , @c_Loadkey        
   END        
   CLOSE @CUR_PACKSLIP        
   DEALLOCATE @CUR_PACKSLIP        
      
      
QUIT_SP:        
   SELECT   TMP.Storerkey        
         ,  TMP.Wavekey        
         ,  TMP.PickHeaderkey        
         ,  TMP.PutawayZone        
         ,  TMP.Printedflag        
         ,  TMP.NoOfSku                
         ,  TMP.NoOfPickLines         
         ,  TMP.OrdSelectkey      
         ,  TMP.ColorCode       
         ,  TMP.ORDDoctype           --CS01      
   FROM #TMP_PSLIP TMP        
   ORDER BY TMP.PickHeaderKey        
         ,  TMP.PutawayZone        
           
        
   IF CURSOR_STATUS( 'VARIABLE', '@CUR_PSLIP') in (0 , 1)          
   BEGIN        
      CLOSE @CUR_PSLIP        
      DEALLOCATE @CUR_PSLIP        
   END        
        
   IF CURSOR_STATUS( 'VARIABLE', '@CUR_PD') in (0 , 1)          
   BEGIN        
      CLOSE @CUR_PD        
      DEALLOCATE @CUR_PD        
   END        
        
   IF CURSOR_STATUS( 'VARIABLE', '@CUR_PACKSLIP') in (0 , 1)          
   BEGIN        
      CLOSE @CUR_PACKSLIP        
      DEALLOCATE @CUR_PACKSLIP        
   END        
        
        
   IF @n_Continue=3  -- Error Occured - Process And Return        
   BEGIN        
      SET @b_Success = 0        
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt        
      BEGIN        
         ROLLBACK TRAN        
      END        
      ELSE        
      BEGIN        
         WHILE @@TRANCOUNT > @n_StartTCnt        
       BEGIN        
            COMMIT TRAN        
         END        
      END        
        
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_GetPickSlipWave26'        
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012        
   END        
   ELSE        
   BEGIN        
      SET @b_Success = 1        
      WHILE @@TRANCOUNT > @n_StartTCnt        
      BEGIN        
         COMMIT TRAN        
      END        
   END        
END -- procedure 

GO
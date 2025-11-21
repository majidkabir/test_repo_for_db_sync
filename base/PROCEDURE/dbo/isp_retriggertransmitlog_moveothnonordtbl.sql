SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/        
/* Store Procedure: isp_ReTriggerTransmitLog_MoveOTHNONORDTBL           */        
/* Creation Date:22-MAY-2020                                            */        
/* Copyright: IDS                                                       */        
/* Written by: LFL                                                      */        
/*                                                                      */        
/* Purpose: - To move archived table setup for dockey is not orderkey   */        
/*            in codelkup back to live db.                              */        
/*                                                                      */        
/* Called By:                                                           */        
/*                                                                      */        
/* PVCS Version: 1.0                                                    */        
/*                                                                      */        
/* Modifications:                                                       */        
/* Date         Author    Ver.  Purposes                                */        
/* 22-MAY-2020  CSCHONG   1.0   WMS-10009 cater for MBOLLOG table       */        
/************************************************************************/        
        
CREATE  PROCEDURE [dbo].[isp_ReTriggerTransmitLog_MoveOTHNONORDTBL]        
     @c_SourceDB    NVARCHAR(30)        
   , @c_TargetDB    NVARCHAR(30)        
   , @c_TableSchema NVARCHAR(10)        
   , @c_TableName   NVARCHAR(50)        
   , @c_KeyColumn   NVARCHAR(50) -- mbolkey        
   , @c_DocKey      NVARCHAR(50)        
   , @b_Success     int           OUTPUT        
   , @n_err         int           OUTPUT        
   , @c_errmsg      NVARCHAR(250) OUTPUT        
   , @b_Debug       INT = 0        
AS        
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
        
DECLARE @c_SQL             NVARCHAR(MAX)        
      , @c_StorerKey       NVARCHAR(15)        
      , @c_Sku             NVARCHAR(20)        
      , @c_Lot             NVARCHAR(10)        
      , @c_Loc             NVARCHAR(10)        
      , @c_Id              NVARCHAR(18)        
      , @c_PackKey         NVARCHAR(10)        
      , @c_ValidFlag       NVARCHAR(1)        
      , @c_ArchiveCop      NVARCHAR(1)        
      , @n_DummyQty        INT        
      , @c_ExecArguments   NVARCHAR(MAX)        
      , @b_RecFound        INT        
      , @n_continue        int         
      , @c_mbolkey         NVARCHAR(50)        
      , @c_loadkey         NVARCHAR(20)        
      , @c_Pickslipno      NVARCHAR(20)        
      , @c_ContainerKey    NVARCHAR(20)        
      , @c_palletkey       NVARCHAR(30)        
      , @c_labelno         NVARCHAR(20)        
      , @n_StartTCnt       INT         
      , @c_ExecSQL         NVARCHAR(MAX)          
      , @c_MbolLineNumber  NVARCHAR(10)        
      , @c_getmbolkey      NVARCHAR(50)        
      , @c_getloadkey      NVARCHAR(20)        
      , @c_LoadLineNumber  NVARCHAR(10)        
      , @c_GetPickslipno   NVARCHAR(20)        
      , @n_cartonno        INT        
      , @c_Getlabelno      NVARCHAR(20)        
      , @c_LabelLine       NVARCHAR(10)        
      , @n_PackSerialNoKey BIGINT        
      , @n_SerialNoKey     BIGINT   
      , @c_SerialNoKey     NVARCHAR(10)        
      , @n_ContainerKey    NVARCHAR(20)          
      , @c_ContainerLineNumber NVARCHAR(20)        
      , @c_PalletLineNumber    NVARCHAR(20)        
      , @n_CTRowNo             INT        
      , @c_CTlabelno           NVARCHAR(20)        
      , @c_Trackingno          NVARCHAR(20)        
      , @c_addwho              NVARCHAR(50)        
      , @c_orderkey            NVARCHAR(20)        
      , @c_OrderLineNumber     NVARCHAR(10)        
      , @c_GetOrderkey         NVARCHAR(20)        
        
   SELECT @n_continue=1        
        
SET @c_ArchiveCop = NULL        
SET @n_DummyQty   = '0'        
        
SET @c_StorerKey = ''        
SET @c_Sku       = ''        
SET @c_Lot       = ''        
SET @c_Loc    = ''        
SET @c_Id        = ''        
        
SET @c_SQL = ''               
        
IF ISNULL(RTRIM(LTRIM(@c_TableName)),'') = UPPER('ORDERS')        
BEGIN        
        
 SET @c_ExecSQL=N' DECLARE CUR_ORDHD CURSOR FAST_FORWARD READ_ONLY FOR'          
                 + ' SELECT DISTINCT OH.Orderkey'          
                 + ' FROM ' + @c_SourceDB + '.dbo.ORDERS OH WITH (NOLOCK) '         
                 + ' WHERE OH.Mbolkey =  @c_DocKey '           
                 + ' ORDER BY OH.Orderkey '          
          
   EXEC sp_executesql @c_ExecSQL,          
                    N'@c_DocKey NVARCHAR(20)',           
                      @c_DocKey         
               
   OPEN CUR_ORDHD          
             
   FETCH NEXT FROM CUR_ORDHD INTO @c_orderkey        
             
   WHILE @@FETCH_STATUS <> -1          
   BEGIN          
      SET @n_Continue = 1          
      
      EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', @c_TableName, 'orderkey', @c_orderkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug             

   IF @b_Success <> 1 AND @c_errmsg <> ''        
   BEGIN        
     SET @n_continue=3        
     GOTO QUIT        
   END        
        
   FETCH NEXT FROM CUR_ORDHD INTO @c_orderkey          
   END          
          
   CLOSE CUR_ORDHD          
   DEALLOCATE CUR_ORDHD         
        
END        
ELSE IF @c_TableName = UPPER('ORDERDETAIL')        
BEGIN        
  SET @c_ExecSQL=N' DECLARE CUR_ODET CURSOR FAST_FORWARD READ_ONLY FOR'          
                 + ' SELECT DISTINCT OH.Orderkey,OD.OrderLineNumber'          
                 + ' FROM ORDERS OH WITH (NOLOCK) '         
                 + ' JOIN ' + @c_SourceDB + '.dbo.ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = OH.Orderkey'           
                 + ' WHERE OH.Mbolkey =  @c_DocKey '           
                 + ' ORDER BY OH.Orderkey,OD.OrderLineNumber '          
          
   EXEC sp_executesql @c_ExecSQL,          
                    N'@c_DocKey NVARCHAR(20)',           
                      @c_DocKey         
           
   OPEN CUR_ODET          
             
   FETCH NEXT FROM CUR_ODET INTO @c_orderkey,@c_OrderLineNumber          
             
   WHILE @@FETCH_STATUS <> -1          
   BEGIN          
      SET @n_Continue = 1          
     IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE orderkey = @c_orderkey)        
     BEGIN        
         EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'ORDERDETAIL', 'Orderkey', @c_orderkey,'OrderLineNumber',@c_OrderLineNumber ,'','','','',         
                                                      @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug        
     END        
           
   IF @b_Success <> 1 AND @c_errmsg <> ''        
   BEGIN        
     SET @n_continue=3        
     GOTO QUIT        
   END        
        
   FETCH NEXT FROM CUR_ODET INTO @c_orderkey,@c_OrderLineNumber            
   END          
          
   CLOSE CUR_ODET          
   DEALLOCATE CUR_ODET         
        
        
END        
ELSE IF ISNULL(RTRIM(LTRIM(@c_TableName)),'') = 'liateDkciP' -- Pass in from isp_MovePickDetail, Then allow to move PickDetail.        
BEGIN        
   SET @c_TableName = REVERSE(@c_TableName)        
   SET @c_TableName = REPLACE(@c_TableName,'%','')        
   SET @c_TableName = ISNULL(RTRIM(LTRIM(@c_TableName)),'')        
        
  DECLARE CUR_PICKDETMBOL CURSOR FAST_FORWARD READ_ONLY FOR         
  SELECT DISTINCT OH.Orderkey         
  FROM ORDERS OH WITH (NOLOCK)        
  WHERE mbolkey = @c_DocKey        
        
         
 OPEN CUR_PICKDETMBOL          
             
   FETCH NEXT FROM CUR_PICKDETMBOL INTO @c_orderkey        
             
   WHILE @@FETCH_STATUS <> -1          
   BEGIN          
      SET @n_Continue = 1          
     IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE orderkey = @c_orderkey)        
     BEGIN        
         EXEC isp_ReTriggerTransmitLog_MovePickDetail @c_SourceDB, @c_TargetDB, 'dbo', @c_TableName, 'orderkey', @c_orderkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug        
     END        
         
   IF @b_Success <> 1 AND @c_errmsg <> ''        
   BEGIN        
     SET @n_continue=3        
     GOTO QUIT        
   END        
        
   FETCH NEXT FROM CUR_PICKDETMBOL INTO @c_orderkey          
   END          
          
   CLOSE CUR_PICKDETMBOL          
   DEALLOCATE CUR_PICKDETMBOL         
        
END        
ELSE IF ISNULL(RTRIM(LTRIM(@c_TableName)),'') = UPPER('ORDERINFO')        
BEGIN        
        
        
  DECLARE CUR_ORDINFO CURSOR FAST_FORWARD READ_ONLY FOR         
  SELECT DISTINCT OH.Orderkey         
  FROM ORDERS OH WITH (NOLOCK)        
  WHERE mbolkey = @c_DocKey        
        
         
 OPEN CUR_ORDINFO          
             
   FETCH NEXT FROM CUR_ORDINFO INTO @c_orderkey        
             
   WHILE @@FETCH_STATUS <> -1          
   BEGIN          
      SET @n_Continue = 1          
     IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE orderkey = @c_orderkey)        
     BEGIN        
         EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', @c_TableName, 'orderkey', @c_orderkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug        
     END        
       
   IF @b_Success <> 1 AND @c_errmsg <> ''        
   BEGIN        
     SET @n_continue=3        
     GOTO QUIT        
   END        
        
   FETCH NEXT FROM CUR_ORDINFO INTO @c_orderkey          
   END          
          
   CLOSE CUR_ORDINFO          
   DEALLOCATE CUR_ORDINFO         
        
END        
ELSE IF @c_TableName = UPPER('MBOL')        
BEGIN        
            
   EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'MBOL', 'mbolkey', @c_DocKey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug        
          
   IF @b_Success <> 1 AND @c_errmsg <> ''        
   BEGIN        
     SET @n_continue=3        
     GOTO QUIT        
   END        
END        
ELSE IF @c_TableName = UPPER('MBOLDETAIL')        
BEGIN        
       
      SET @c_StorerKey = ''        
      SET @c_ExecSQL = ''        
                     
     SET @c_ExecSQL=N' DECLARE CUR_MBOLDET CURSOR FAST_FORWARD READ_ONLY FOR'          
                 + ' SELECT DISTINCT mbolkey,mbollinenumber'          
                 + ' FROM ' + @c_SourceDB + '.dbo.MBOLDETAIL MB WITH (NOLOCK)'           
                 + ' WHERE MB.Mbolkey =  @c_DocKey '           
                 + ' ORDER BY mbolkey,mbollinenumber '          
          
   EXEC sp_executesql @c_ExecSQL,          
                    N'@c_DocKey NVARCHAR(20)',           
                      @c_DocKey        
                    
   OPEN CUR_MBOLDET          
             
   FETCH NEXT FROM CUR_MBOLDET INTO @c_getmbolkey,@c_MbolLineNumber          
             
   WHILE @@FETCH_STATUS <> -1          
   BEGIN          
      SET @n_Continue = 1          
           
     IF EXISTS (SELECT 1 FROM MBOL WITH (NOLOCK) WHERE mbolkey = @c_getmbolkey)        
     BEGIN        
         EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'MBOLDETAIL', 'mbolkey', @c_getmbolkey,'mbollinenumber',@c_MbolLineNumber ,'','','','',         
                                                      @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug        
     END        
      
   IF @b_Success <> 1 AND @c_errmsg <> ''        
   BEGIN        
     SET @n_continue=3        
     GOTO QUIT        
   END        
        
   FETCH NEXT FROM CUR_MBOLDET INTO @c_getmbolkey,@c_MbolLineNumber            
   END          
          
   CLOSE CUR_MBOLDET          
   DEALLOCATE CUR_MBOLDET          
END        
ELSE IF @c_TableName = UPPER('LOADPLAN')        
BEGIN        
        
  DECLARE CUR_LOAD CURSOR FAST_FORWARD READ_ONLY FOR         
  SELECT DISTINCT OH.loadkey         
  FROM ORDERS OH WITH (NOLOCK)        
  WHERE mbolkey = @c_DocKey        
        
         
 OPEN CUR_LOAD          
             
   FETCH NEXT FROM CUR_LOAD INTO @c_loadkey        
             
   WHILE @@FETCH_STATUS <> -1          
   BEGIN          
     SET @n_Continue = 1          
     IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE loadkey = @c_loadkey)        
     BEGIN        
         EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'LOADPLAN', 'loadkey', @c_loadkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug        
     END        
        
   IF @b_Success <> 1 AND @c_errmsg <> ''        
   BEGIN        
     SET @n_continue=3        
     GOTO QUIT        
   END        
        
   FETCH NEXT FROM CUR_LOAD INTO @c_loadkey          
   END          
          
   CLOSE CUR_LOAD          
   DEALLOCATE CUR_LOAD         
        
END        
ELSE IF @c_TableName = UPPER('LOADPLANDETAIL')        
BEGIN        
                           
SET @c_ExecSQL=N' DECLARE CUR_LOADPLANDET CURSOR FAST_FORWARD READ_ONLY FOR'          
                 + ' SELECT DISTINCT LP.loadkey,LD.LoadLineNumber'          
                 + ' FROM ORDERS OH WITH (NOLOCK) '         
                 + ' JOIN LOADPLAN LP WITH (NOLOCK) ON LP.loadkey = OH.Loadkey'        
                 + ' JOIN '+ @c_SourceDB + '.dbo.LOADPLANDETAIL LD WITH (NOLOCK) ON LD.loadkey = LP.loadkey '           
                 + ' WHERE OH.mbolkey =  @c_DocKey '           
                 + ' ORDER BY LP.loadkey,LD.LoadLineNumber '          
          
   EXEC sp_executesql @c_ExecSQL,          
                    N'@c_DocKey NVARCHAR(20)',           
                      @c_DocKey         
                    
   OPEN CUR_LOADPLANDET          
             
   FETCH NEXT FROM CUR_LOADPLANDET INTO @c_getloadkey,@c_LoadLineNumber          
             
   WHILE @@FETCH_STATUS <> -1          
   BEGIN          
      SET @n_Continue = 1          
       
     IF EXISTS (SELECT 1 FROM LOADPLAN WITH (NOLOCK) WHERE loadkey = @c_getloadkey )        
     BEGIN        
         EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'LOADPLANDETAIL', 'loadkey', @c_getloadkey,'LoadLineNumber',@c_LoadLineNumber ,'','','','',         
                 @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug        
     END        
        
   IF @b_Success <> 1 AND @c_errmsg <> ''        
   BEGIN        
     SET @n_continue=3        
     GOTO QUIT        
   END        
        
   FETCH NEXT FROM CUR_LOADPLANDET INTO @c_getloadkey,@c_LoadLineNumber            
   END          
          
   CLOSE CUR_LOADPLANDET          
   DEALLOCATE CUR_LOADPLANDET          
        
END        
ELSE IF  @c_TableName = UPPER('PICKHEADER')        
BEGIN                  
        
        DECLARE CUR_PICKDET CURSOR FAST_FORWARD READ_ONLY FOR         
        SELECT DISTINCT OH.Orderkey,OH.loadkey         
        FROM ORDERS OH WITH (NOLOCK)        
        WHERE mbolkey = @c_DocKey        
        
         
       OPEN CUR_PICKDET          
             
         FETCH NEXT FROM CUR_PICKDET INTO @c_orderkey,@c_getloadkey        
             
         WHILE @@FETCH_STATUS <> -1          
         BEGIN          
             SET @n_Continue = 1          
             EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'PICKHEADER', 'orderkey', @c_orderkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug        
        
           IF @b_Success <> 1 AND @c_errmsg <> ''        
           BEGIN        
             SET @n_continue=3        
             GOTO QUIT        
           END        
                       
           SET @c_Pickslipno = ''        
        
           SELECT @c_Pickslipno = Pickheaderkey        
           FROM PICKHEADER WITH (NOLOCK)        
           WHERE Orderkey = @c_orderkey        
           
         IF ISNULL(@c_Pickslipno,'') = ''        
         BEGIN        
           IF ISNULL(@c_getloadkey,'') <> ''        
           BEGIN        
             EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'PICKHEADER', 'ExternOrderkey', @c_getloadkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug        
                   
            IF @b_Success <> 1 AND @c_errmsg <> ''        
            BEGIN        
              SET @n_continue=3        
              GOTO QUIT        
            END        
             
           END        
         END        
         FETCH NEXT FROM CUR_PICKDET INTO @c_orderkey ,@c_getloadkey         
         END          
          
         CLOSE CUR_PICKDET          
         DEALLOCATE CUR_PICKDET         
               
END        
ELSE IF  @c_TableName = UPPER('PACKHEADER')        
BEGIN        
                     
    DECLARE CUR_PACKHEADER CURSOR FAST_FORWARD READ_ONLY FOR         
        SELECT DISTINCT OH.Orderkey,OH.loadkey         
        FROM ORDERS OH WITH (NOLOCK)        
        WHERE mbolkey = @c_DocKey        
        
         
        OPEN CUR_PACKHEADER          
             
         FETCH NEXT FROM CUR_PACKHEADER INTO @c_orderkey,@c_getloadkey        
             
         WHILE @@FETCH_STATUS <> -1          
         BEGIN          
        
             SET @n_Continue = 1          
             EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'PACKHEADER', 'orderkey', @c_orderkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug        
        
           IF @b_Success <> 1 AND @c_errmsg <> ''        
           BEGIN        
             SET @n_continue=3        
             GOTO QUIT        
           END        
                        
         
          SELECT @c_Pickslipno = pickslipno        
          FROM PACKHEADER WITH (NOLOCK)        
          WHERE Orderkey = @c_DocKey        
        
         IF ISNULL(@c_Pickslipno,'') = ''      
         BEGIN        
           IF ISNULL(@c_getloadkey,'') <> ''        
           BEGIN        
             EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'PACKHEADER', 'loadkey', @c_getloadkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug        
                   
            IF @b_Success <> 1 AND @c_errmsg <> ''        
            BEGIN        
              SET @n_continue=3        
              GOTO QUIT        
            END        
             
           END        
          END        
         FETCH NEXT FROM CUR_PACKHEADER INTO @c_orderkey  ,@c_getloadkey        
         END          
          
         CLOSE CUR_PACKHEADER          
         DEALLOCATE CUR_PACKHEADER         
END          
ELSE IF  @c_TableName = UPPER('PACKDETAIL')        
BEGIN        
        
      DECLARE CUR_PACKDET CURSOR FAST_FORWARD READ_ONLY FOR         
      SELECT DISTINCT OH.Orderkey,OH.loadkey         
      FROM ORDERS OH WITH (NOLOCK)        
      WHERE mbolkey = @c_DocKey             
         
      OPEN CUR_PACKDET       
             
      FETCH NEXT FROM CUR_PACKDET INTO @c_orderkey,@c_getloadkey        
             
      WHILE @@FETCH_STATUS <> -1          
      BEGIN          
        
      SET @c_loadkey = ''        
      SET @c_Pickslipno = ''        
        
      SELECT @c_Pickslipno = Pickheaderkey        
      FROM PICKHEADER WITH (NOLOCK)        
      WHERE Orderkey = @c_orderkey        
        
      IF ISNULL(@c_Pickslipno,'') = ''        
      BEGIN             
        
       SELECT @c_Pickslipno = Pickheaderkey        
       FROM PICKHEADER WITH (NOLOCK)        
       WHERE ExternOrderkey = @c_getloadkey        
        
      END        
        
     SET @c_ExecSQL=N' DECLARE CUR_PADDET CURSOR FAST_FORWARD READ_ONLY FOR'          
                 + ' SELECT DISTINCT Pickslipno,cartonno,labelno,LabelLine'          
                 + ' FROM ' + @c_SourceDB + '.dbo.PACKDETAIL PD WITH (NOLOCK)'           
                 + ' WHERE PD.Pickslipno =  @c_Pickslipno '           
                 + ' ORDER BY Pickslipno,cartonno,labelno,LabelLine '          
          
   EXEC sp_executesql @c_ExecSQL,          
                   N'@c_Pickslipno NVARCHAR(20)',           
                     @c_Pickslipno         
           
   OPEN CUR_PADDET          
             
   FETCH NEXT FROM CUR_PADDET INTO @c_GetPickslipno,@n_cartonno,@c_Getlabelno , @c_LabelLine        
             
   WHILE @@FETCH_STATUS <> -1          
   BEGIN          
      SET @n_Continue = 1                 
     IF ISNULL(@c_GetPickslipno,'') <> ''        
     BEGIN        
         EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'PACKDETAIL', 'pickslipno', @c_GetPickslipno,'cartonno',@n_cartonno ,        
                'labelno',@c_Getlabelno,'labelline',@c_LabelLine,@b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug        
     END        
     
   IF @b_Success <> 1 AND @c_errmsg <> ''        
   BEGIN        
     SET @n_continue=3        
     GOTO QUIT        
   END        
        
      FETCH NEXT FROM CUR_PADDET INTO @c_GetPickslipno,@n_cartonno,@c_Getlabelno , @c_LabelLine           
      END          
          
      CLOSE CUR_PADDET          
      DEALLOCATE CUR_PADDET          
        
   FETCH NEXT FROM CUR_PACKDET INTO @c_orderkey ,@c_getloadkey         
   END          
          
   CLOSE CUR_PACKDET          
   DEALLOCATE CUR_PACKDET         
END        
ELSE IF  @c_TableName = UPPER('PACKINFO')        
BEGIN        
        
      DECLARE CUR_PACKINFO CURSOR FAST_FORWARD READ_ONLY FOR         
      SELECT DISTINCT OH.Orderkey,OH.loadkey         
      FROM ORDERS OH WITH (NOLOCK)        
      WHERE mbolkey = @c_DocKey        
                 
      OPEN CUR_PACKINFO          
             
      FETCH NEXT FROM CUR_PACKINFO INTO @c_orderkey,@c_getloadkey        
             
      WHILE @@FETCH_STATUS <> -1          
      BEGIN         
       
      SET @c_Pickslipno = ''        
      SET @c_ExecSQL = ''         
        
   SELECT @c_Pickslipno = Pickheaderkey        
   FROM PICKHEADER WITH (NOLOCK)        
   WHERE Orderkey = @c_orderkey        
        
   IF ISNULL(@c_Pickslipno,'') = ''        
   BEGIN                     
    SELECT @c_Pickslipno = Pickheaderkey        
    FROM PICKHEADER WITH (NOLOCK)        
    WHERE ExternOrderkey = @c_getloadkey                
   END        
           
     SET @c_ExecSQL=N' DECLARE CUR_PIF CURSOR FAST_FORWARD READ_ONLY FOR'          
                 + ' SELECT DISTINCT Pickslipno,cartonno'          
                 + ' FROM ' + @c_SourceDB + '.dbo.PACKINFO PIF WITH (NOLOCK)'           
                 + ' WHERE PIF.Pickslipno =  @c_Pickslipno '           
                 + ' ORDER BY Pickslipno,cartonno '          
          
   EXEC sp_executesql @c_ExecSQL,          
                    N'@c_Pickslipno NVARCHAR(20)',           
                      @c_Pickslipno         
                    
   OPEN CUR_PIF          
             
   FETCH NEXT FROM CUR_PIF INTO @c_GetPickslipno,@n_cartonno        
             
   WHILE @@FETCH_STATUS <> -1          
   BEGIN          
      SET @n_Continue = 1          
       
     IF ISNULL(@c_GetPickslipno,'') <> ''        
     BEGIN        
         EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'PACKINFO', 'pickslipno', @c_GetPickslipno,'cartonno',@n_cartonno ,        
                                                      '','','','',@b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug        
     END        
        
   IF @b_Success <> 1 AND @c_errmsg <> ''        
   BEGIN        
     SET @n_continue=3        
     GOTO QUIT        
   END        
        
   FETCH NEXT FROM CUR_PIF INTO @c_GetPickslipno,@n_cartonno         
   END          
          
   CLOSE CUR_PIF          
   DEALLOCATE CUR_PIF        
        
  FETCH NEXT FROM CUR_PACKINFO INTO @c_orderkey,@c_getloadkey        
   END          
          
   CLOSE CUR_PACKINFO          
   DEALLOCATE CUR_PACKINFO          
        
END        
ELSE IF  @c_TableName = UPPER('PICKINGINFO')        
BEGIN        
       DECLARE CUR_PICKINGINFO CURSOR FAST_FORWARD READ_ONLY FOR         
      SELECT DISTINCT OH.Orderkey,OH.loadkey         
      FROM ORDERS OH WITH (NOLOCK)        
      WHERE mbolkey = @c_DocKey        
                 
      OPEN CUR_PICKINGINFO          
             
      FETCH NEXT FROM CUR_PICKINGINFO INTO @c_orderkey,@c_getloadkey        
             
      WHILE @@FETCH_STATUS <> -1          
      BEGIN         
               
      SET @c_Pickslipno = ''        
      SET @c_ExecSQL = ''        
        
   SELECT @c_Pickslipno = Pickheaderkey        
   FROM PICKHEADER WITH (NOLOCK)        
   WHERE Orderkey = @c_orderkey        
        
   IF ISNULL(@c_Pickslipno,'') = ''        
   BEGIN                    
    SELECT @c_Pickslipno = Pickheaderkey        
    FROM PICKHEADER WITH (NOLOCK)        
    WHERE ExternOrderkey = @c_getloadkey                
   END        
        
    IF @c_Pickslipno <> ''        
    BEGIN        
       EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'PICKINGINFO', 'Pickslipno', @c_Pickslipno, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug        
    END        
        
 FETCH NEXT FROM CUR_PICKINGINFO INTO @c_orderkey,@c_getloadkey          
 END          
          
 CLOSE CUR_PICKINGINFO          
 DEALLOCATE CUR_PICKINGINFO        
         
END        
ELSE IF  @c_TableName = UPPER('PACKSERIALNO')        
BEGIN        
        
     DECLARE CUR_PACKSERIALNO CURSOR FAST_FORWARD READ_ONLY FOR         
      SELECT DISTINCT OH.Orderkey,OH.loadkey         
      FROM ORDERS OH WITH (NOLOCK)        
      WHERE mbolkey = @c_DocKey               
         
      OPEN CUR_PACKSERIALNO          
             
      FETCH NEXT FROM CUR_PACKSERIALNO INTO @c_orderkey,@c_getloadkey        
             
      WHILE @@FETCH_STATUS <> -1          
      BEGIN         
              
      SET @c_Pickslipno = ''        
      SET @c_ExecSQL = ''        
        
   SELECT @c_Pickslipno = Pickheaderkey        
   FROM PICKHEADER WITH (NOLOCK)        
   WHERE Orderkey = @c_orderkey        
        
   IF ISNULL(@c_Pickslipno,'') = ''        
   BEGIN        
    SELECT @c_Pickslipno = Pickheaderkey        
    FROM PICKHEADER WITH (NOLOCK)        
    WHERE ExternOrderkey = @c_getloadkey                
   END        
        
SET @c_ExecSQL=N' DECLARE CUR_PAS CURSOR FAST_FORWARD READ_ONLY FOR'          
                 + ' SELECT DISTINCT PackSerialNoKey'          
                 + ' FROM ' + @c_SourceDB + '.dbo.PACKSERIALNO PAS WITH (NOLOCK)'           
                 + ' WHERE PAS.Pickslipno =  @c_Pickslipno '           
                 + ' ORDER BY PackSerialNoKey '          
          
   EXEC sp_executesql @c_ExecSQL,          
                    N'@c_Pickslipno NVARCHAR(20)',           
                      @c_Pickslipno         
           
   OPEN CUR_PAS          
             
   FETCH NEXT FROM CUR_PAS INTO @n_PackSerialNoKey        
             
   WHILE @@FETCH_STATUS <> -1          
   BEGIN          
      SET @n_Continue = 1          
     IF ISNULL(@n_PackSerialNoKey,'') <> ''        
     BEGIN        
       EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'PACKSERIALNO', 'PackSerialNoKey', @n_PackSerialNoKey,'','' ,        
                                                   '','','','',@b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug        
    END        
      
   IF @b_Success <> 1 AND @c_errmsg <> ''        
   BEGIN        
     SET @n_continue=3        
     GOTO QUIT        
   END        
        
   FETCH NEXT FROM CUR_PAS INTO @n_PackSerialNoKey        
   END          
          
   CLOSE CUR_PAS          
   DEALLOCATE CUR_PAS        
        
 FETCH NEXT FROM CUR_PACKSERIALNO INTO @c_orderkey,@c_getloadkey          
 END          
          
 CLOSE CUR_PACKSERIALNO          
 DEALLOCATE CUR_PACKSERIALNO         
END        
ELSE IF  @c_TableName = UPPER('SERIALNO')        
BEGIN        
        
     DECLARE CUR_SERIALNO CURSOR FAST_FORWARD READ_ONLY FOR         
      SELECT DISTINCT OH.Orderkey,OH.loadkey         
      FROM ORDERS OH WITH (NOLOCK)        
      WHERE mbolkey = @c_DocKey        
                 
      OPEN CUR_SERIALNO          
             
      FETCH NEXT FROM CUR_SERIALNO INTO @c_orderkey,@c_getloadkey        
             
      WHILE @@FETCH_STATUS <> -1          
      BEGIN         
                
      SET @c_Pickslipno = ''        
      SET @c_ExecSQL = ''        
        
   SELECT @c_Pickslipno = Pickheaderkey        
   FROM PICKHEADER WITH (NOLOCK)        
   WHERE Orderkey = @c_orderkey        
        
   IF ISNULL(@c_Pickslipno,'') = ''        
   BEGIN        
    SELECT @c_Pickslipno = Pickheaderkey        
    FROM PICKHEADER WITH (NOLOCK)        
    WHERE ExternOrderkey = @c_getloadkey                
   END        
        
SET @c_ExecSQL=N' DECLARE CUR_SN CURSOR FAST_FORWARD READ_ONLY FOR'          
                 + ' SELECT DISTINCT SN.SerialNoKey'          
                 + ' FROM ' + @c_SourceDB + '.dbo.SERIALNO SN WITH (NOLOCK)'           
                 + ' LEFT JOIN PACKSERIALNO PAS WITH (NOLOCK) ON PAS.SerialNo = SN.SerialNo'              
                 + ' WHERE PAS.Pickslipno =  @c_Pickslipno OR SN.OrderKey = @c_orderkey '   
                 + ' AND ISNULL(SN.SerialNoKey,'''') <> '''' '           
                 + ' ORDER BY SN.SerialNoKey '          
          
   EXEC sp_executesql @c_ExecSQL,          
                    N'@c_Pickslipno NVARCHAR(20), @c_orderkey NVARCHAR(20)',           
                      @c_Pickslipno, @c_orderkey         
           
   OPEN CUR_SN          
             
   FETCH NEXT FROM CUR_SN INTO @c_SerialNoKey        
             
   WHILE @@FETCH_STATUS <> -1          
   BEGIN          
      SET @n_Continue = 1          
     IF ISNULL(@c_SerialNoKey,'') <> ''        
     BEGIN        
         EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'SERIALNO', 'SerialNoKey', @c_SerialNoKey,'','' ,        
                                                      '','','','',@b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug        
     END        
      
   IF @b_Success <> 1 AND @c_errmsg <> ''        
   BEGIN        
     SET @n_continue=3        
     GOTO QUIT        
   END        
        
   FETCH NEXT FROM CUR_SN INTO @c_SerialNoKey        
   END          
          
   CLOSE CUR_SN          
   DEALLOCATE CUR_SN        
        
 FETCH NEXT FROM CUR_SERIALNO INTO @c_orderkey,@c_getloadkey          
 END          
          
 CLOSE CUR_SERIALNO           
 DEALLOCATE CUR_SERIALNO         
END        
ELSE IF  @c_TableName = UPPER('CONTAINER')        
BEGIN        
        
     DECLARE CUR_CONTAINER CURSOR FAST_FORWARD READ_ONLY FOR         
      SELECT DISTINCT OH.Orderkey,OH.loadkey         
      FROM ORDERS OH WITH (NOLOCK)        
      WHERE mbolkey = @c_DocKey        
                 
      OPEN CUR_CONTAINER          
             
      FETCH NEXT FROM CUR_CONTAINER INTO @c_orderkey,@c_getloadkey        
             
      WHILE @@FETCH_STATUS <> -1          
      BEGIN         
       
      SET @c_ExecSQL = ''        
      SET @c_Pickslipno = ''        
        
   SELECT @c_Pickslipno = Pickslipno        
   FROM PACKHEADER WITH (NOLOCK)        
   WHERE Orderkey = @c_orderkey        
        
   IF ISNULL(@c_Pickslipno,'') = ''        
   BEGIN        
    SELECT @c_Pickslipno = Pickslipno        
    FROM PACKHEADER WITH (NOLOCK)        
    WHERE loadkey = @c_getloadkey                
   END        
        
    SET @c_ExecSQL=N' DECLARE CUR_CONT CURSOR FAST_FORWARD READ_ONLY FOR'          
                 + ' SELECT DISTINCT C.ContainerKey '          
                 + ' FROM PACKHEADER PH (NOLOCK) '        
                 + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +        
                 + ' JOIN ' + @c_SourceDB + '.dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON (PD.LabelNo = CD.Palletkey OR PD.UPC = CD.Palletkey) '        
                 + ' JOIN ' + @c_SourceDB + '.dbo.CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '          
                 + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLET PL (NOLOCK) ON CD.Palletkey = PL.Palletkey '          
                 + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLETDETAIL PLD WITH (NOLOCK) ON PL.PalletKey = PLD.PalletKey '           
                 + ' WHERE PH.PickSlipNo  =  @c_Pickslipno '           
                 + ' UNION' + CHAR(13) +        
                 + ' SELECT DISTINCT C.ContainerKey'          
                 + ' FROM ' + @c_SourceDB + '.dbo.CONTAINER C WITH (NOLOCK)'           
                 + ' WHERE C.OtherReference =  @c_DocKey '          
                 + ' UNION' + CHAR(13) +          
                 + ' SELECT DISTINCT C.ContainerKey '          
                 + ' FROM PACKHEADER PH (NOLOCK) '        
                 + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +        
                 + ' JOIN ' + @c_SourceDB + '.dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON PD.UPC = CD.Palletkey '        
                 + ' JOIN ' + @c_SourceDB + '.dbo.CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '          
                 + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLET PL (NOLOCK) ON CD.Palletkey = PL.Palletkey '          
                 + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLETDETAIL PLD WITH (NOLOCK)  ON PL.PalletKey = PLD.PalletKey '           
                 + ' WHERE PH.PickSlipNo  =  @c_Pickslipno '          
                 + ' UNION' + CHAR(13) +          
                 + ' SELECT DISTINCT C.ContainerKey '          
                 + ' FROM PACKHEADER PH (NOLOCK) '        
                + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +        
                 + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLETDETAIL PLD WITH (NOLOCK) ON PD.LabelNo = PLD.CaseId AND PD.StorerKey = PLD.StorerKey '           
                 + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLET PL (NOLOCK) ON PLD.Palletkey = PL.Palletkey '                           
                 + ' JOIN ' + @c_SourceDB + '.dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON PLD.Palletkey = CD.Palletkey '        
                 + ' JOIN ' + @c_SourceDB + '.dbo.CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '          
                 + ' WHERE PH.PickSlipNo  =  @c_Pickslipno '          
                 + ' ORDER BY C.ContainerKey '           
           
        
   EXEC sp_executesql @c_ExecSQL,          
                    N'@c_Pickslipno NVARCHAR(20) , @c_DocKey NVARCHAR(20)',           
                      @c_Pickslipno,@c_DocKey        
           
   OPEN CUR_CONT          
             
   FETCH NEXT FROM CUR_CONT INTO @c_ContainerKey        
             
   WHILE @@FETCH_STATUS <> -1          
   BEGIN          
      SET @n_Continue = 1          
     IF ISNULL(@c_ContainerKey,'') <> ''        
     BEGIN        
         EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'CONTAINER', 'ContainerKey', @c_ContainerKey,'','' ,        
                                                      '','','','',@b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug        
     END        
       
   IF @b_Success <> 1 AND @c_errmsg <> ''        
   BEGIN        
     SET @n_continue=3        
     GOTO QUIT        
   END        
        
   FETCH NEXT FROM CUR_CONT INTO @c_ContainerKey        
   END          
          
   CLOSE CUR_CONT          
   DEALLOCATE CUR_CONT        
        
  
 FETCH NEXT FROM CUR_CONTAINER INTO @c_orderkey,@c_getloadkey          
 END          
          
 CLOSE CUR_CONTAINER          
 DEALLOCATE CUR_CONTAINER         
END        
ELSE IF  @c_TableName = UPPER('CONTAINERDETAIL')        
BEGIN        
              
     DECLARE CUR_CONTAINERDETAIL CURSOR FAST_FORWARD READ_ONLY FOR         
      SELECT DISTINCT OH.Orderkey,OH.loadkey         
      FROM ORDERS OH WITH (NOLOCK)        
      WHERE mbolkey = @c_DocKey        
                 
      OPEN CUR_CONTAINERDETAIL          
             
      FETCH NEXT FROM CUR_CONTAINERDETAIL INTO @c_orderkey,@c_getloadkey        
             
      WHILE @@FETCH_STATUS <> -1          
      BEGIN         
      
      SET @c_ExecSQL = ''        
      SET @c_Pickslipno = ''        
        
   SELECT @c_Pickslipno = Pickslipno        
   FROM PACKHEADER WITH (NOLOCK)        
   WHERE Orderkey = @c_orderkey        
        
   IF ISNULL(@c_Pickslipno,'') = ''        
   BEGIN        
    SELECT @c_Pickslipno = Pickslipno        
    FROM PACKHEADER WITH (NOLOCK)        
    WHERE loadkey = @c_getloadkey               
   END        
        
          SET @c_ExecSQL=N' DECLARE CUR_CONDET CURSOR FAST_FORWARD READ_ONLY FOR'          
                 + ' SELECT DISTINCT C.ContainerKey , CD.ContainerLineNumber '          
                 + ' FROM PACKHEADER PH (NOLOCK) '        
                 + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +        
                 + ' JOIN ' + @c_SourceDB + '.dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON (PD.LabelNo = CD.Palletkey OR PD.UPC = CD.Palletkey) '        
                 + ' JOIN CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '          
                 + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLET PL (NOLOCK) ON CD.Palletkey = PL.Palletkey '          
                 + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLETDETAIL PLD WITH (NOLOCK) ON PL.PalletKey = PLD.PalletKey '           
                 + ' WHERE PH.PickSlipNo  =  @c_Pickslipno '           
                 + ' UNION' + CHAR(13) +        
                 + ' SELECT DISTINCT C.ContainerKey , CD.ContainerLineNumber'          
                 + ' FROM CONTAINER C WITH (NOLOCK)'           
                 + ' JOIN ' + @c_SourceDB + '.dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON CD.ContainerKey = C.ContainerKey '        
                 + ' WHERE C.OtherReference =  @c_DocKey '          
                 + ' UNION' + CHAR(13) +          
                 + ' SELECT DISTINCT C.ContainerKey, CD.ContainerLineNumber '          
                 + ' FROM PACKHEADER PH (NOLOCK) '        
                 + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +        
                 + ' JOIN ' + @c_SourceDB + '.dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON PD.UPC = CD.Palletkey '        
                 + ' JOIN CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '          
                 + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLET PL (NOLOCK) ON CD.Palletkey = PL.Palletkey '          
                 + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLETDETAIL PLD WITH (NOLOCK)  ON PL.PalletKey = PLD.PalletKey '           
                 + ' WHERE PH.PickSlipNo  =  @c_Pickslipno '          
                 + ' UNION' + CHAR(13) +          
                 + ' SELECT DISTINCT C.ContainerKey, CD.ContainerLineNumber '          
                 + ' FROM PACKHEADER PH (NOLOCK) '        
                 + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +        
                 + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLETDETAIL PLD WITH (NOLOCK) ON PD.LabelNo = PLD.CaseId AND PD.StorerKey = PLD.StorerKey '           
                 + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLET PL (NOLOCK) ON PLD.Palletkey = PL.Palletkey '                           
                 + ' JOIN ' + @c_SourceDB + '.dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON PLD.Palletkey = CD.Palletkey '        
                 + ' JOIN dbo.CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '          
                 + ' WHERE PH.PickSlipNo  =  @c_Pickslipno '          
                 + ' ORDER BY C.ContainerKey, CD.ContainerLineNumber '           
          
   EXEC sp_executesql @c_ExecSQL,          
                    N'@c_Pickslipno NVARCHAR(20) ,@c_DocKey NVARCHAR(20)',           
                      @c_Pickslipno ,@c_DocKey         
           
   OPEN CUR_CONDET          
             
   FETCH NEXT FROM CUR_CONDET INTO @c_ContainerKey, @c_ContainerLineNumber        
             
   WHILE @@FETCH_STATUS <> -1          
   BEGIN          
      SET @n_Continue = 1                  
         EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'CONTAINERDETAIL', 'ContainerKey', @c_ContainerKey,'ContainerLineNumber',@c_ContainerLineNumber ,        
                                                      '','','','',@b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug               

   IF @b_Success <> 1 AND @c_errmsg <> ''        
   BEGIN        
     SET @n_continue=3        
     GOTO QUIT        
   END        
        
   FETCH NEXT FROM CUR_CONDET INTO @c_ContainerKey, @c_ContainerLineNumber        
   END          
          
   CLOSE CUR_CONDET          
   DEALLOCATE CUR_CONDET        
       
 FETCH NEXT FROM CUR_CONTAINERDETAIL INTO @c_orderkey,@c_getloadkey          
 END          
          
 CLOSE CUR_CONTAINERDETAIL          
 DEALLOCATE CUR_CONTAINERDETAIL         
END        
ELSE IF  @c_TableName = UPPER('PALLET')        
BEGIN         
        
DECLARE CUR_PLTMAIN CURSOR FAST_FORWARD READ_ONLY FOR         
      SELECT DISTINCT OH.Orderkey,OH.loadkey         
      FROM ORDERS OH WITH (NOLOCK)        
      WHERE mbolkey = @c_DocKey        
                 
      OPEN CUR_PLTMAIN          
             
      FETCH NEXT FROM CUR_PLTMAIN INTO @c_orderkey,@c_getloadkey        
             
      WHILE @@FETCH_STATUS <> -1          
      BEGIN         
       
      SET @c_ExecSQL = ''        
      SET @c_Pickslipno = ''        
        
   SELECT @c_Pickslipno = Pickslipno        
   FROM PACKHEADER WITH (NOLOCK)        
   WHERE Orderkey = @c_orderkey        
        
   IF ISNULL(@c_Pickslipno,'') = ''        
   BEGIN        
    SELECT @c_Pickslipno = Pickslipno        
    FROM PACKHEADER WITH (NOLOCK)        
    WHERE loadkey = @c_getloadkey            
   END        
        
          SET @c_ExecSQL=N' DECLARE CUR_PLT CURSOR FAST_FORWARD READ_ONLY FOR'          
                 + ' SELECT DISTINCT PL.Palletkey '          
                 + ' FROM PACKHEADER PH (NOLOCK) '        
                 + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +        
                 + ' JOIN CONTAINERDETAIL CD WITH (NOLOCK) ON (PD.LabelNo = CD.Palletkey OR PD.UPC = CD.Palletkey) '        
                 + ' JOIN CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '          
                 + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLET PL (NOLOCK) ON CD.Palletkey = PL.Palletkey '          
                 + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLETDETAIL PLD WITH (NOLOCK) ON PL.PalletKey = PLD.PalletKey '           
                 + ' WHERE PH.PickSlipNo  =  @c_Pickslipno '           
                 + ' UNION' + CHAR(13) +        
                 + ' SELECT DISTINCT PL.Palletkey '          
                 + ' FROM PACKHEADER PH (NOLOCK) '        
                 + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +        
                 + ' JOIN CONTAINERDETAIL CD WITH (NOLOCK) ON PD.UPC = CD.Palletkey '        
                 + ' JOIN CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '          
                 + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLET PL (NOLOCK) ON CD.Palletkey = PL.Palletkey '          
                 + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLETDETAIL PLD WITH (NOLOCK)  ON PL.PalletKey = PLD.PalletKey '           
                 + ' WHERE PH.PickSlipNo  =  @c_Pickslipno '          
                 + ' UNION' + CHAR(13) +          
                 + ' SELECT DISTINCT PL.Palletkey '          
                 + ' FROM PACKHEADER PH (NOLOCK) '        
                 + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +        
                 + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLETDETAIL PLD WITH (NOLOCK) ON PD.LabelNo = PLD.CaseId AND PD.StorerKey = PLD.StorerKey '           
                 + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLET PL (NOLOCK) ON PLD.Palletkey = PL.Palletkey '                           
                 + ' JOIN CONTAINERDETAIL CD WITH (NOLOCK) ON PLD.Palletkey = CD.Palletkey '        
                 + ' JOIN dbo.CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '          
                 + ' WHERE PH.PickSlipNo  =  @c_Pickslipno '          
                 + ' ORDER BY PL.Palletkey '           
              
      EXEC sp_executesql @c_ExecSQL,          
                       N'@c_Pickslipno NVARCHAR(20) ',           
                         @c_Pickslipno         
                       
   OPEN CUR_PLT          
             
   FETCH NEXT FROM CUR_PLT INTO @c_palletkey        
             
   WHILE @@FETCH_STATUS <> -1          
   BEGIN          
   IF ISNULL(@c_palletkey,'') <> ''        
   BEGIN        
      EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'PALLET', 'PALLETKEY', @c_palletkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug        
   END        
   
   IF @b_Success <> 1 AND @c_errmsg <> ''        
   BEGIN        
     SET @n_continue=3        
     GOTO QUIT        
   END        
        
   FETCH NEXT FROM CUR_PLT INTO @c_palletkey        
   END          
          
   CLOSE CUR_PLT          
   DEALLOCATE CUR_PLT         
          
  FETCH NEXT FROM CUR_PLTMAIN INTO @c_orderkey,@c_getloadkey          
  END          
          
 CLOSE CUR_PLTMAIN          
 DEALLOCATE CUR_PLTMAIN         
END        
ELSE IF  @c_TableName = UPPER('PALLETDETAIL')        
BEGIN        

DECLARE CUR_PLTDETMAIN CURSOR FAST_FORWARD READ_ONLY FOR         
      SELECT DISTINCT OH.Orderkey,OH.loadkey         
      FROM ORDERS OH WITH (NOLOCK)        
      WHERE mbolkey = @c_DocKey        
        
         
      OPEN CUR_PLTDETMAIN          
             
      FETCH NEXT FROM CUR_PLTDETMAIN INTO @c_orderkey,@c_getloadkey        
             
      WHILE @@FETCH_STATUS <> -1          
      BEGIN         
       
      SET @c_ExecSQL = ''        
      SET @c_Pickslipno = ''        
        
   SELECT @c_Pickslipno = Pickslipno        
   FROM PACKHEADER WITH (NOLOCK)        
   WHERE Orderkey = @c_orderkey        
        
   IF ISNULL(@c_Pickslipno,'') = ''        
   BEGIN        
    SELECT @c_Pickslipno = Pickslipno        
    FROM PACKHEADER WITH (NOLOCK)        
    WHERE loadkey = @c_getloadkey               
   END        
                 
          SET @c_ExecSQL=N' DECLARE CUR_PALDET CURSOR FAST_FORWARD READ_ONLY FOR'          
                 + ' SELECT DISTINCT PL.Palletkey,PLD.PalletLineNumber '          
                 + ' FROM PACKHEADER PH (NOLOCK) '        
                 + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +        
                 + ' JOIN CONTAINERDETAIL CD WITH (NOLOCK) ON (PD.LabelNo = CD.Palletkey OR PD.UPC = CD.Palletkey) '        
                 + ' JOIN CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '          
                 + ' LEFT JOIN dbo.PALLET PL (NOLOCK) ON CD.Palletkey = PL.Palletkey '          
                 + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLETDETAIL PLD WITH (NOLOCK) ON PL.PalletKey = PLD.PalletKey '           
                 + ' WHERE PH.PickSlipNo  =  @c_Pickslipno '           
                 + ' UNION' + CHAR(13) +        
                 + ' SELECT DISTINCT PL.Palletkey ,PLD.PalletLineNumber'          
                 + ' FROM PACKHEADER PH (NOLOCK) '        
                 + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +        
                 + ' JOIN CONTAINERDETAIL CD WITH (NOLOCK) ON PD.UPC = CD.Palletkey '        
                 + ' JOIN CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '          
                 + ' LEFT JOIN PALLET PL (NOLOCK) ON CD.Palletkey = PL.Palletkey '          
                 + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLETDETAIL PLD WITH (NOLOCK)  ON PL.PalletKey = PLD.PalletKey '           
                 + ' WHERE PH.PickSlipNo  =  @c_Pickslipno '          
                 + ' UNION' + CHAR(13) +          
                 + ' SELECT DISTINCT PL.Palletkey ,PLD.PalletLineNumber '          
                 + ' FROM PACKHEADER PH (NOLOCK) '        
                 + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +        
                 + ' LEFT JOIN PALLETDETAIL PLD WITH (NOLOCK) ON PD.LabelNo = PLD.CaseId AND PD.StorerKey = PLD.StorerKey '           
                 + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLET PL (NOLOCK) ON PLD.Palletkey = PL.Palletkey '                           
                 + ' JOIN CONTAINERDETAIL CD WITH (NOLOCK) ON PLD.Palletkey = CD.Palletkey '        
                 + ' JOIN dbo.CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '          
                 + ' WHERE PH.PickSlipNo  =  @c_Pickslipno '          
                 + ' ORDER BY PL.Palletkey '           
              
      EXEC sp_executesql @c_ExecSQL,          
                       N'@c_Pickslipno NVARCHAR(20) ',           
                         @c_Pickslipno          
           
   OPEN CUR_PALDET          
             
   FETCH NEXT FROM CUR_PALDET INTO @c_Palletkey, @c_PalletLineNumber        
             
   WHILE @@FETCH_STATUS <> -1          
   BEGIN          
      SET @n_Continue = 1          
   IF ISNULL(@c_Palletkey,'') <> '' AND ISNULL(@c_PalletLineNumber,'') <> ''        
   BEGIN        
         EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'PALLETDETAIL', 'Palletkey', @c_palletkey,'PalletLineNumber',@c_PalletLineNumber ,        
                '','','','',@b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug        
   END        
       
   IF @b_Success <> 1 AND @c_errmsg <> ''        
   BEGIN        
     SET @n_continue=3        
     GOTO QUIT        
   END        
        
   FETCH NEXT FROM CUR_PALDET INTO @c_Palletkey, @c_PalletLineNumber        
   END          
          
   CLOSE CUR_PALDET          
   DEALLOCATE CUR_PALDET        
        
           
  FETCH NEXT FROM CUR_PLTDETMAIN INTO @c_orderkey,@c_getloadkey          
  END          
          
 CLOSE CUR_PLTDETMAIN          
 DEALLOCATE CUR_PLTDETMAIN         
END        
ELSE IF  @c_TableName = UPPER('CARTONTRACK')        
BEGIN        
        
      SET @c_labelno = ''        
    
     DECLARE CUR_CTKMAIN CURSOR FAST_FORWARD READ_ONLY FOR         
      SELECT DISTINCT OH.Orderkey,OH.loadkey         
      FROM ORDERS OH WITH (NOLOCK)        
      WHERE mbolkey = @c_DocKey               
         
      OPEN CUR_CTKMAIN          
             
      FETCH NEXT FROM CUR_CTKMAIN INTO @c_orderkey,@c_getloadkey        
             
      WHILE @@FETCH_STATUS <> -1          
      BEGIN         
      
      SET @c_ExecSQL = ''        
      SET @c_Pickslipno = ''        
        
   SELECT @c_Pickslipno = Pickslipno        
   FROM PACKHEADER WITH (NOLOCK)        
   WHERE Orderkey = @c_orderkey        
        
   IF ISNULL(@c_Pickslipno,'') = ''        
   BEGIN        
    SELECT @c_Pickslipno = Pickslipno        
    FROM PACKHEADER WITH (NOLOCK)        
    WHERE loadkey = @c_getloadkey               
   END        
          
      SELECT @c_labelno = labelno        
      FROM PACKDETAIL WITH (NOLOCK)        
      WHERE pickslipno = @c_Pickslipno        
        
   IF ISNULL(@c_labelno,'') = ''        
   BEGIN        
     SET @c_labelno = @c_DocKey        
   END        
        
    SET @c_ExecSQL=N' DECLARE CUR_CTK CURSOR FAST_FORWARD READ_ONLY FOR'          
                 + ' SELECT DISTINCT RowRef,labelno,trackingno,Addwho'          
                 + ' FROM ' + @c_SourceDB + '.dbo.CARTONTRACK CT WITH (NOLOCK)'           
                 + ' WHERE CT.labelno =  @c_labelno OR CT.labelno = @c_orderkey'           
                 + ' ORDER BY RowRef '          
          
   EXEC sp_executesql @c_ExecSQL,          
                    N'@c_labelno NVARCHAR(20),@c_orderkey NVARCHAR(20)',           
                      @c_labelno, @c_orderkey         
           
   OPEN CUR_CTK          
             
   FETCH NEXT FROM CUR_CTK INTO @n_CTRowNo,@c_CTlabelno,@c_trackingno,@c_Addwho        
             
   WHILE @@FETCH_STATUS <> -1          
   BEGIN          
        
      SET @n_Continue = 1                 
         EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'CARTONTRACK', 'RowRef', @n_CTRowNo,'labelno',@c_CTlabelno ,        
                                                     'trackingno',@c_trackingno,'Addwho',@c_Addwho,@b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug                
   IF @b_Success <> 1 AND @c_errmsg <> ''        
   BEGIN        
     SET @n_continue=3        
     GOTO QUIT        
   END        
        
   FETCH NEXT FROM CUR_CTK INTO @n_CTRowNo,@c_CTlabelno,@c_trackingno,@c_Addwho        
   END          
          
   CLOSE CUR_CTK          
   DEALLOCATE CUR_CTK         
   FETCH NEXT FROM CUR_CTKMAIN INTO @c_orderkey,@c_getloadkey          
  END          
          
 CLOSE CUR_CTKMAIN          
 DEALLOCATE CUR_CTKMAIN         
END        
        
QUIT:        
        
IF @n_continue=3  -- Error Occured - Process And Return        
   BEGIN        
      SET @b_success = 0        
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt        
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
      --execute nsp_logerror @n_err, @c_errmsg, 'isp_RetriggerInterfaceSO'        
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012        
      RETURN        
   END        
   ELSE        
   BEGIN        
      SET @b_success = 1        
      WHILE @@TRANCOUNT > @n_StartTCnt        
      BEGIN        
         COMMIT TRAN        
      END        
      RETURN        
   END 


GO
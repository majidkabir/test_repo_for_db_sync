SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store Procedure: isp_ReTriggerTransmitLog_MoveOTHTBL                 */  
/* Creation Date:03-FEB-2020                                            */  
/* Copyright: IDS                                                       */  
/* Written by: LFL                                                      */  
/*                                                                      */  
/* Purpose: - To move archived table setup in codelkup back to live db. */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Modifications:                                                       */  
/* Date         Author    Ver.  Purposes                                */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp_ReTriggerTransmitLog_MoveOTHTBL]  
     @c_SourceDB    NVARCHAR(30)  
   , @c_TargetDB    NVARCHAR(30)  
   , @c_TableSchema NVARCHAR(10)  
   , @c_TableName   NVARCHAR(50)  
   , @c_KeyColumn   NVARCHAR(50) -- OrderKey  
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
      , @c_ExecSQL         NVARCHAR(4000)    
      , @c_MbolLineNumber  NVARCHAR(10)  
      , @c_getmbolkey      NVARCHAR(50)  
      , @c_getloadkey      NVARCHAR(20)  
      , @c_LoadLineNumber  NVARCHAR(10)  
      , @c_GetPickslipno   NVARCHAR(20)  
      , @n_cartonno        INT  
      , @c_Getlabelno      NVARCHAR(20)  
      , @c_LabelLine       NVARCHAR(10)  
      , @n_PackSerialNoKey BIGINT  
      , @n_ContainerKey    NVARCHAR(20)    
      , @c_ContainerLineNumber NVARCHAR(20)  
      , @c_PalletLineNumber    NVARCHAR(20)  
      , @n_CTRowNo             INT  
      , @c_CTlabelno           NVARCHAR(20)  
      , @c_Trackingno          NVARCHAR(20)  
      , @c_addwho              NVARCHAR(50)  
  
   SELECT @n_continue=1  
  
SET @c_ArchiveCop = NULL  
SET @n_DummyQty   = '0'  
  
SET @c_StorerKey = ''  
SET @c_Sku       = ''  
SET @c_Lot       = ''  
SET @c_Loc       = ''  
SET @c_Id        = ''  
  
SET @c_SQL = ''  
  
IF @c_TableName = UPPER('MBOL')  
BEGIN  
      SET @c_mbolkey = ''  
      SELECT @c_mbolkey = mbolkey  
         ,@c_StorerKey = storerkey  
      FROM ORDERS WITH (NOLOCK)  
      WHERE Orderkey = @c_DocKey  
  
   EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'MBOL', 'mbolkey', @c_mbolkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
    
   IF @b_Success <> 1 AND @c_errmsg <> ''  
   BEGIN  
     SET @n_continue=3  
     GOTO QUIT  
   END  
END  
ELSE IF @c_TableName = UPPER('MBOLDETAIL')  
BEGIN  
  
   --   IF @c_KeyColumn = UPPER('MBOLKEY')  
   --BEGIN  
  
       SET @c_mbolkey = ''  
     SET @c_StorerKey = ''  
         SET @c_ExecSQL = ''  
  
       SELECT @c_mbolkey = mbolkey  
             ,@c_StorerKey = storerkey  
          FROM ORDERS WITH (NOLOCK)  
          WHERE Orderkey = @c_DocKey  
  
     SET @c_ExecSQL=N' DECLARE CUR_DET CURSOR FAST_FORWARD READ_ONLY FOR'    
                 + ' SELECT DISTINCT mbolkey,mbollinenumber'    
                 + ' FROM ' + @c_SourceDB + '.dbo.MBOLDETAIL MB WITH (NOLOCK)'     
                 + ' WHERE MB.Mbolkey =  @c_mbolkey '     
                 + ' ORDER BY mbolkey,mbollinenumber '    
    
   EXEC sp_executesql @c_ExecSQL,    
            N'@c_mbolkey NVARCHAR(20)',     
              @c_mbolkey   
     
   OPEN CUR_DET    
       
   FETCH NEXT FROM CUR_DET INTO @c_getmbolkey,@c_MbolLineNumber    
       
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      SET @n_Continue = 1    
      --BEGIN TRAN    
       
   --  EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'MBOLDETAIL', 'mbolkey', @c_mbolkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
   --END  
   --ELSE  
   --BEGIN  
     IF EXISTS (SELECT 1 FROM MBOL WITH (NOLOCK) WHERE mbolkey = @c_mbolkey)  
   BEGIN  
         EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'MBOLDETAIL', 'mbolkey', @c_mbolkey,'mbollinenumber',@c_MbolLineNumber ,'','','','',   
                 @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
         END  
   --END  
   IF @b_Success <> 1 AND @c_errmsg <> ''  
   BEGIN  
     SET @n_continue=3  
     GOTO QUIT  
   END  
  
   FETCH NEXT FROM CUR_DET INTO @c_getmbolkey,@c_MbolLineNumber      
   END    
    
   CLOSE CUR_DET    
   DEALLOCATE CUR_DET    
END  
ELSE IF @c_TableName = UPPER('LOADPLAN')  
BEGIN  
  
      SET @c_loadkey = ''  
      SELECT @c_loadkey = loadkey  
         ,@c_StorerKey = storerkey  
      FROM ORDERS WITH (NOLOCK)  
      WHERE Orderkey = @c_DocKey  
  
    IF @c_loadkey <> ''  
    BEGIN  
        EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'LOADPLAN', 'loadkey', @c_loadkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
  
   IF @b_Success <> 1 AND @c_errmsg <> ''  
   BEGIN  
     SET @n_continue=3  
     GOTO QUIT  
   END  
     
   END  
  
END  
ELSE IF @c_TableName = UPPER('LOADPLANDETAIL')  
BEGIN  
        
   --IF @c_KeyColumn = UPPER('LOADKEY')  
   --BEGIN  
     SET @c_loadkey = ''  
           SET @c_ExecSQL = ''  
     SELECT @c_loadkey = loadkey  
         ,@c_StorerKey = storerkey  
     FROM ORDERS WITH (NOLOCK)  
     WHERE Orderkey = @c_DocKey  
  
SET @c_ExecSQL=N' DECLARE CUR_LPDET CURSOR FAST_FORWARD READ_ONLY FOR'    
                 + ' SELECT DISTINCT loadkey,LoadLineNumber'    
                 + ' FROM ' + @c_SourceDB + '.dbo.LOADPLANDETAIL LD WITH (NOLOCK)'     
                 + ' WHERE LD.loadkey =  @c_loadkey '     
                 + ' ORDER BY loadkey,LoadLineNumber '    
    
   EXEC sp_executesql @c_ExecSQL,    
            N'@c_loadkey NVARCHAR(20)',     
              @c_loadkey   
     
   OPEN CUR_LPDET    
       
   FETCH NEXT FROM CUR_LPDET INTO @c_getloadkey,@c_LoadLineNumber    
       
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      SET @n_Continue = 1    
      --BEGIN TRAN    
       
   --  EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'MBOLDETAIL', 'mbolkey', @c_mbolkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
   --END  
   --ELSE  
   --BEGIN  
     IF EXISTS (SELECT 1 FROM LOADPLAN WITH (NOLOCK) WHERE loadkey = @c_loadkey )  
   BEGIN  
         EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'LOADPLANDETAIL', 'loadkey', @c_getloadkey,'LoadLineNumber',@c_LoadLineNumber ,'','','','',   
                 @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
         END  
   --END  
   IF @b_Success <> 1 AND @c_errmsg <> ''  
   BEGIN  
     SET @n_continue=3  
     GOTO QUIT  
   END  
  
   FETCH NEXT FROM CUR_LPDET INTO @c_getloadkey,@c_LoadLineNumber      
   END    
    
CLOSE CUR_LPDET    
   DEALLOCATE CUR_LPDET    
  
   --  IF EXISTS (SELECT 1 FROM LOADPLAD WITH (NOLOCK) WHERE loadkey = @c_loadkey )  
   --BEGIN  
   --     EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'LOADPLANDETAIL', 'orderkey', @c_DocKey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
   --  END  
   --      IF @b_Success <> 1 AND @c_errmsg <> ''  
   --      BEGIN  
   --         SET @n_continue=3  
   --         GOTO QUIT  
   --      END  
      
   -- END  
END  
ELSE IF  @c_TableName = UPPER('PICKHEADER')  
BEGIN  
  
      SET @c_loadkey = ''  
   SET @c_Pickslipno = ''  
  
   SELECT @c_loadkey = loadkey  
   FROM ORDERS (NOLOCK)  
   where OrderKey = @c_DocKey  
  
        EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'PICKHEADER', 'orderkey', @c_DocKey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
  
      IF @b_Success <> 1 AND @c_errmsg <> ''  
   BEGIN  
     SET @n_continue=3  
     GOTO QUIT  
   END  
  
  
    SELECT @c_Pickslipno = Pickheaderkey  
       FROM PICKHEADER WITH (NOLOCK)  
       WHERE Orderkey = @c_DocKey  
     
   IF ISNULL(@c_Pickslipno,'') = ''  
   BEGIN  
         SELECT @c_loadkey = loadkey  
         FROM ORDERS (NOLOCK)  
         where OrderKey = @c_DocKey  
             
     IF ISNULL(@c_loadkey,'') <> ''  
     BEGIN  
       EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'PICKHEADER', 'ExternOrderkey', @c_loadkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
             
      IF @b_Success <> 1 AND @c_errmsg <> ''  
      BEGIN  
    SET @n_continue=3  
    GOTO QUIT  
      END  
       
     END  
     
  END  
         
END  
ELSE IF  @c_TableName = UPPER('PACKHEADER')  
BEGIN  
  
      SET @c_loadkey = ''  
   SET @c_Pickslipno = ''  
  
   SELECT @c_Pickslipno = Pickheaderkey  
   FROM PICKHEADER WITH (NOLOCK)  
   WHERE Orderkey = @c_DocKey  
  
   IF ISNULL(@c_Pickslipno,'') = ''  
   BEGIN  
     SELECT @c_loadkey = loadkey  
         ,@c_StorerKey = storerkey  
      FROM ORDERS WITH (NOLOCK)  
      WHERE Orderkey = @c_DocKey  
  
    SELECT @c_Pickslipno = Pickheaderkey  
    FROM PICKHEADER WITH (NOLOCK)  
    WHERE ExternOrderkey = @c_loadkey  
  
   END  
  
   IF @c_Pickslipno <> ''  
    BEGIN  
     EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'PACKHEADER', 'Pickslipno', @c_Pickslipno, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
   END  
END    
ELSE IF  @c_TableName = UPPER('PACKDETAIL')  
BEGIN  
  
      SET @c_loadkey = ''  
   SET @c_Pickslipno = ''  
  
   SELECT @c_Pickslipno = Pickheaderkey  
   FROM PICKHEADER WITH (NOLOCK)  
   WHERE Orderkey = @c_DocKey  
  
   IF ISNULL(@c_Pickslipno,'') = ''  
   BEGIN  
     SELECT @c_loadkey = loadkey  
         ,@c_StorerKey = storerkey  
      FROM ORDERS WITH (NOLOCK)  
      WHERE Orderkey = @c_DocKey  
  
    SELECT @c_Pickslipno = Pickheaderkey  
    FROM PICKHEADER WITH (NOLOCK)  
    WHERE ExternOrderkey = @c_loadkey  
  
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
      --BEGIN TRAN    
       
   --  EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'MBOLDETAIL', 'mbolkey', @c_mbolkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
   --END  
   --ELSE  
   --BEGIN  
     IF ISNULL(@c_GetPickslipno,'') <> ''  
   BEGIN  
         EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'PACKDETAIL', 'pickslipno', @c_GetPickslipno,'cartonno',@n_cartonno ,  
                'labelno',@c_Getlabelno,'labelline',@c_LabelLine,@b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
         END  
   --END  
   IF @b_Success <> 1 AND @c_errmsg <> ''  
   BEGIN  
     SET @n_continue=3  
     GOTO QUIT  
   END  
  
   FETCH NEXT FROM CUR_PADDET INTO @c_GetPickslipno,@n_cartonno,@c_Getlabelno , @c_LabelLine     
   END    
    
   CLOSE CUR_PADDET    
   DEALLOCATE CUR_PADDET    
  
   --IF @c_Pickslipno <> ''  
   -- BEGIN  
   --       EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'PACKDETAIL', 'Pickslipno', @c_Pickslipno, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
   --END  
END  
ELSE IF  @c_TableName = UPPER('PACKINFO')  
BEGIN  
  
      SET @c_loadkey = ''  
    SET @c_Pickslipno = ''  
      SET @c_ExecSQL = ''   
  
   SELECT @c_Pickslipno = Pickheaderkey  
   FROM PICKHEADER WITH (NOLOCK)  
   WHERE Orderkey = @c_DocKey  
  
   IF ISNULL(@c_Pickslipno,'') = ''  
   BEGIN  
     SELECT @c_loadkey = loadkey  
         ,@c_StorerKey = storerkey  
      FROM ORDERS WITH (NOLOCK)  
      WHERE Orderkey = @c_DocKey  
  
    SELECT @c_Pickslipno = Pickheaderkey  
    FROM PICKHEADER WITH (NOLOCK)  
    WHERE ExternOrderkey = @c_loadkey  
  
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
      --BEGIN TRAN    
       
   --  EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'MBOLDETAIL', 'mbolkey', @c_mbolkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
   --END  
   --ELSE  
   --BEGIN  
     IF ISNULL(@c_GetPickslipno,'') <> ''  
   BEGIN  
         EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'PACKINFO', 'pickslipno', @c_GetPickslipno,'cartonno',@n_cartonno ,  
                '','','','',@b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
         END  
   --END  
   IF @b_Success <> 1 AND @c_errmsg <> ''  
   BEGIN  
     SET @n_continue=3  
     GOTO QUIT  
   END  
  
   FETCH NEXT FROM CUR_PIF INTO @c_GetPickslipno,@n_cartonno   
   END    
    
   CLOSE CUR_PIF    
   DEALLOCATE CUR_PIF  
  
   --IF @c_Pickslipno <> ''  
   -- BEGIN  
   --  EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'PACKINFO', 'Pickslipno', @c_Pickslipno, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
   --END  
END  
ELSE IF  @c_TableName = UPPER('PICKINGINFO')  
BEGIN  
  
      SET @c_loadkey = ''  
   SET @c_Pickslipno = ''  
  
   SELECT @c_Pickslipno = Pickheaderkey  
   FROM PICKHEADER WITH (NOLOCK)  
   WHERE Orderkey = @c_DocKey  
  
   IF ISNULL(@c_Pickslipno,'') = ''  
   BEGIN  
     SELECT @c_loadkey = loadkey  
         ,@c_StorerKey = storerkey  
      FROM ORDERS WITH (NOLOCK)  
      WHERE Orderkey = @c_DocKey  
  
    SELECT @c_Pickslipno = Pickheaderkey  
    FROM PICKHEADER WITH (NOLOCK)  
    WHERE ExternOrderkey = @c_loadkey  
  
   END  
  
   IF @c_Pickslipno <> ''  
    BEGIN  
     EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'PICKINGINFO', 'Pickslipno', @c_Pickslipno, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
       END  
END  
ELSE IF  @c_TableName = UPPER('PACKSERIALNO')  
BEGIN  
  
      SET @c_loadkey = ''  
    SET @c_Pickslipno = ''  
      SET @c_ExecSQL = ''  
  
   SELECT @c_Pickslipno = Pickheaderkey  
   FROM PICKHEADER WITH (NOLOCK)  
   WHERE Orderkey = @c_DocKey  
  
   IF ISNULL(@c_Pickslipno,'') = ''  
   BEGIN  
     SELECT @c_loadkey = loadkey  
         ,@c_StorerKey = storerkey  
      FROM ORDERS WITH (NOLOCK)  
      WHERE Orderkey = @c_DocKey  
  
    SELECT @c_Pickslipno = Pickheaderkey  
    FROM PICKHEADER WITH (NOLOCK)  
    WHERE ExternOrderkey = @c_loadkey  
  
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
     IF ISNULL(@c_GetPickslipno,'') <> ''  
   BEGIN  
         EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'PACKSERIALNO', 'PackSerialNoKey', @n_PackSerialNoKey,'','' ,  
                '','','','',@b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
         END  
   --END  
   IF @b_Success <> 1 AND @c_errmsg <> ''  
   BEGIN  
     SET @n_continue=3  
     GOTO QUIT  
   END  
  
   FETCH NEXT FROM CUR_PAS INTO @n_PackSerialNoKey  
   END    
    
   CLOSE CUR_PAS    
   DEALLOCATE CUR_PAS  
  
   --IF @c_Pickslipno <> ''  
   -- BEGIN  
   --  EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'PACKSERIALNO', 'Pickslipno', @c_Pickslipno, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
   --END  
END  
  
ELSE IF  @c_TableName = UPPER('CONTAINER')  
BEGIN  
  
      SET @c_mbolkey = ''  
      SET @c_ExecSQL = ''  
      SELECT @c_mbolkey = mbolkey  
         ,@c_StorerKey = storerkey  
      FROM ORDERS WITH (NOLOCK)  
      WHERE Orderkey = @c_DocKey  
  
     SET @c_ExecSQL=N' DECLARE CUR_CONT CURSOR FAST_FORWARD READ_ONLY FOR'    
                 + ' SELECT DISTINCT ContainerKey'    
                 + ' FROM ' + @c_SourceDB + '.dbo.CONTAINER CONT WITH (NOLOCK)'     
                 + ' WHERE CONT.OtherReference =  @c_mbolkey '     
                 + ' ORDER BY ContainerKey '    
    
   EXEC sp_executesql @c_ExecSQL,    
            N'@c_mbolkey NVARCHAR(20)',     
              @c_mbolkey   
     
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
   --END  
   IF @b_Success <> 1 AND @c_errmsg <> ''  
   BEGIN  
     SET @n_continue=3  
     GOTO QUIT  
   END  
  
   FETCH NEXT FROM CUR_CONT INTO @c_ContainerKey  
   END    
    
   CLOSE CUR_CONT    
   DEALLOCATE CUR_CONT  
  
  -- EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'CONTAINER', 'OtherReference', @c_mbolkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
  
END  
ELSE IF  @c_TableName = UPPER('CONTAINERDETAIL')  
BEGIN  
  
      SET @c_mbolkey = ''  
      SET @c_ExecSQL = ''  
      SELECT @c_mbolkey = mbolkey  
         ,@c_StorerKey = storerkey  
      FROM ORDERS WITH (NOLOCK)  
      WHERE Orderkey = @c_DocKey  
  
        SET @c_ContainerKey = ''  
  
     SELECT @c_ContainerKey = ContainerKey  
     FROM CONTAINER WITH (NOLOCK)  
     WHERE  OtherReference= @c_mbolkey  
  
          SET @c_ExecSQL=N' DECLARE CUR_CONDET CURSOR FAST_FORWARD READ_ONLY FOR'    
                 + ' SELECT DISTINCT ContainerKey, ContainerLineNumber '    
                 + ' FROM ' + @c_SourceDB + '.dbo.CONTAINERDETAIL CONDET WITH (NOLOCK)'     
                 + ' WHERE CONDET.ContainerKey =  @c_ContainerKey '     
                 + ' ORDER BY ContainerKey, ContainerLineNumber '    
    
   EXEC sp_executesql @c_ExecSQL,    
            N'@c_ContainerKey NVARCHAR(20)',     
              @c_ContainerKey   
     
   OPEN CUR_CONDET    
       
   FETCH NEXT FROM CUR_CONDET INTO @c_ContainerKey, @c_ContainerLineNumber  
       
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      SET @n_Continue = 1    
     IF ISNULL(@c_ContainerKey,'') <> ''  
   BEGIN  
         EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'CONTAINERDETAIL', 'ContainerKey', @c_ContainerKey,'ContainerLineNumber',@c_ContainerLineNumber ,  
                '','','','',@b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
         END  
   --END  
   IF @b_Success <> 1 AND @c_errmsg <> ''  
   BEGIN  
     SET @n_continue=3  
     GOTO QUIT  
   END  
  
   FETCH NEXT FROM CUR_CONDET INTO @c_ContainerKey, @c_ContainerLineNumber  
   END    
    
   CLOSE CUR_CONDET    
   DEALLOCATE CUR_CONDET  
     --IF ISNULL(@c_ContainerKey,'') <> ''  
     --BEGIN  
     --   EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'CONTAINERDETAIL', 'ContainerKey', @c_ContainerKey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
     --END  
  
END  
ELSE IF  @c_TableName = UPPER('PALLET')  
BEGIN  
  
      SET @c_mbolkey = ''  
    SET @c_palletkey = ''  
      SELECT @c_mbolkey = mbolkey  
         ,@c_StorerKey = storerkey  
      FROM ORDERS WITH (NOLOCK)  
      WHERE Orderkey = @c_DocKey  
  
   SELECT @c_palletkey = CONTD.Palletkey  
   FROM CONTAINER CONT WITH (NOLOCK)  
   JOIN CONTAINERDETAIL CONTD WITH (NOLOCK) ON CONTD.ContainerKey = CONT.ContainerKey  
   WHERE CONT.OtherReference = @c_mbolkey  
  
   IF ISNULL(@c_palletkey,'') <> ''  
   BEGIN  
      EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'PALLET', 'PALLETKEY', @c_palletkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
      END  
END  
ELSE IF  @c_TableName = UPPER('PALLETDETAIL')  
BEGIN  
  
      SET @c_mbolkey = ''  
    SET @c_palletkey = ''  
      SET @c_ExecSQL = ''  
      SELECT @c_mbolkey = mbolkey  
         ,@c_StorerKey = storerkey  
      FROM ORDERS WITH (NOLOCK)  
      WHERE Orderkey = @c_DocKey  
  
   SELECT @c_palletkey = CONTD.Palletkey  
   FROM CONTAINER CONT WITH (NOLOCK)  
   JOIN CONTAINERDETAIL CONTD WITH (NOLOCK) ON CONTD.ContainerKey = CONT.ContainerKey  
   WHERE CONT.OtherReference = @c_mbolkey  
  
SET @c_ExecSQL=N' DECLARE CUR_PALDET CURSOR FAST_FORWARD READ_ONLY FOR'    
                 + ' SELECT DISTINCT Palletkey, PalletLineNumber '    
                 + ' FROM ' + @c_SourceDB + '.dbo.PALLETDETAIL PALDET WITH (NOLOCK)'     
                 + ' WHERE PALDET.Palletkey =  @c_palletkey '     
                 + ' ORDER BY Palletkey, PalletLineNumber '    
    
   EXEC sp_executesql @c_ExecSQL,    
            N'@c_palletkey NVARCHAR(20)',     
              @c_palletkey   
     
   OPEN CUR_PALDET    
       
   FETCH NEXT FROM CUR_PALDET INTO @c_Palletkey, @c_PalletLineNumber  
       
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      SET @n_Continue = 1    
     IF ISNULL(@c_ContainerKey,'') <> ''  
   BEGIN  
         EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'PALLETDETAIL', 'Palletkey', @c_palletkey,'PalletLineNumber',@c_PalletLineNumber ,  
                '','','','',@b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
         END  
   --END  
   IF @b_Success <> 1 AND @c_errmsg <> ''  
   BEGIN  
     SET @n_continue=3  
     GOTO QUIT  
   END  
  
   FETCH NEXT FROM CUR_PALDET INTO @c_Palletkey, @c_PalletLineNumber  
   END    
    
   CLOSE CUR_PALDET    
   DEALLOCATE CUR_PALDET  
  
   --IF ISNULL(@c_palletkey,'') <> ''  
   --BEGIN  
   --   EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'PALLETDETAIL', 'PALLETKEY', @c_palletkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
   --   END  
  
END  
ELSE IF  @c_TableName = UPPER('CARTONTRACK')  
BEGIN  
  
      SET @c_labelno = ''  
  
    SET @c_loadkey = ''  
    SET @c_Pickslipno = ''  
      SET @c_ExecSQL = ''  
  
   SELECT @c_Pickslipno = Pickslipno  
   FROM PACKHEADER WITH (NOLOCK)  
   WHERE Orderkey = @c_DocKey  
  
   IF ISNULL(@c_Pickslipno,'') = ''  
   BEGIN  
     SELECT @c_loadkey = loadkey  
         ,@c_StorerKey = storerkey  
      FROM ORDERS WITH (NOLOCK)  
      WHERE Orderkey = @c_DocKey  
  
    SELECT @c_Pickslipno = Pickslipno  
    FROM PACKHEADER WITH (NOLOCK)  
    WHERE loadkey = @c_loadkey  
  
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
                 + ' WHERE CT.labelno =  @c_labelno OR CT.labelno = @c_DocKey'     
                 + ' ORDER BY RowRef '    
    
   EXEC sp_executesql @c_ExecSQL,    
            N'@c_labelno NVARCHAR(20),@c_DocKey NVARCHAR(20)',     
              @c_labelno, @c_DocKey   
     
   OPEN CUR_CTK    
       
   FETCH NEXT FROM CUR_CTK INTO @n_CTRowNo,@c_CTlabelno,@c_trackingno,@c_Addwho  
       
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
  
      SET @n_Continue = 1    
   --  IF ISNULL(@n_CTRowNo,'') <> ''  
   --BEGIN  
  
            --select @n_CTRowNo '@n_CTRowNo', @c_CTlabelno 'labelno' , @c_trackingno '@c_trackingno', @c_Addwho 'Addwho'  
         EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'CARTONTRACK', 'RowRef', @n_CTRowNo,'labelno',@c_CTlabelno ,  
                'trackingno',@c_trackingno,'Addwho',@c_Addwho,@b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
      --   END  
   --END  
   IF @b_Success <> 1 AND @c_errmsg <> ''  
   BEGIN  
     SET @n_continue=3  
     GOTO QUIT  
   END  
  
   FETCH NEXT FROM CUR_CTK INTO @n_CTRowNo,@c_CTlabelno,@c_trackingno,@c_Addwho  
   END    
    
   CLOSE CUR_CTK    
   DEALLOCATE CUR_CTK   
  
   --IF ISNULL(@c_palletkey,'') <> ''  
   --BEGIN  
     -- EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'CARTONTRACK', 'Labelno', @c_labelno, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
          
     --   IF NOT EXISTS (SELECT 1 FROM CARTONTRACK WITH (NOLOCK) WHERE Labelno = @c_labelno)  
     --   BEGIN  
     --EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'CARTONTRACK', 'Labelno', @c_DocKey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
     --   END  
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
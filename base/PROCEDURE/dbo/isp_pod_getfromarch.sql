SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_POD_GetFromArch                                     */
/* Creation Date: 19-OCT-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-3234 - Retrieve and move POD from archive to production */
/*                                                                      */
/* Called By:  nep_pod_maintenance.tab_pod.ue_search                    */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 03-Jan-2018  Wan       WMS-3662 - Add Externloadkey to WMS POD module*/
/************************************************************************/
CREATE PROC [dbo].[isp_POD_GetFromArch] 
            @c_SQLCondition  NVARCHAR(MAX)
   				 ,@b_Success       INT            OUTPUT
				   ,@n_Err           INT            OUTPUT 
				   ,@c_ErrMsg        NVARCHAR(250)  OUTPUT            
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt       INT
         , @n_Continue        INT
         , @n_Cnt             INT     
         , @c_Orderkey        NVARCHAR(10)
         , @c_ArchiveDB       NVARCHAR(30)
         , @c_ExecSQL         NVARCHAR(4000)
         , @c_PODFromArchive  NVARCHAR(30)
         
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1
      
   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END
   
   SET @c_ArchiveDB = ''
   SELECT @c_ArchiveDB = ISNULL(RTRIM(NSQLValue),'') FROM NSQLCONFIG WITH (NOLOCK)
   WHERE ConfigKey='ArchiveDBName'
   
   SET @c_PODFromArchive = ""
   SELECT @c_PODFromArchive = ISNULL(NSQLValue,'') 
   FROM nSqlConfig (nolock)
   WHERE ConfigKey = 'PODFromArchive'

   IF @c_ArchiveDB = '' OR @c_PODFromArchive <> '1' OR ISNULL(@c_SQLCondition,'') = ''
   BEGIN
      GOTO QUIT_SP
   END
   
   SET @c_ExecSQL=N' DECLARE CUR_POD CURSOR FAST_FORWARD READ_ONLY FOR'
                 + ' SELECT TOP 1000 POD.Orderkey'
                 + ' FROM ' + @c_ArchiveDB + '.dbo.POD POD WITH (NOLOCK)'
                 + ' LEFT JOIN ' + @c_ArchiveDB + '.dbo.ORDERS ORDERS WITH (NOLOCK) ON (POD.Orderkey = ORDERS.Orderkey)'
                 + ' WHERE ' + @c_SQLCondition
                 + ' ORDER BY POD.EditDate DESC, POD.Orderkey DESC'

   EXECUTE sp_ExecuteSQL @c_ExecSQL
 
   OPEN CUR_POD
   
   FETCH NEXT FROM CUR_POD INTO @c_Orderkey
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @n_Continue = 1
      BEGIN TRAN
      
      SET @c_ExecSQL=N' INSERT INTO POD ('
               + 'Mbolkey,           '
	             + 'Mbollinenumber,    '
	             + 'LoadKey,           '
	             + 'ExternLoadKey,     '               --(Wan01)
	             + 'OrderKey,          '
	             + 'BuyerPO,           '
	             + 'ExternOrderKey,    '
	             + 'InvoiceNo,         '
	             + '[Status],          '
	             + 'ActualDeliveryDate,'
	             + 'InvDespatchDate,   '
	             + 'PodReceivedDate,   '
	             + 'PodFiledDate,      '
	             + 'InvCancelDate,     '
	             + 'RedeliveryDate,    '
	             + 'RedeliveryCount,   '
	             + 'FullRejectDate,    '
	             + 'ReturnRefNo,       '
	             + 'PartialRejectDate, '
	             + 'RejectReasonCode,  '
	             + 'PoisonFormDate,    '
	             + 'PoisonFormNo,      '
	             + 'ChequeNo,          '
	             + 'ChequeAmount,      '
	             + 'ChequeDate,        '
	             + 'Notes,             '
	             + 'Notes2,            '
	             + 'PODDef01,          '
	             + 'PODDef02,          '
	             + 'PODDef03,          '
	             + 'PODDef04,          '
	             + 'PODDef05,          '
	             + 'PODDef06,          '
	             + 'PODDef07,          '
	             + 'PODDef08,          '
	             + 'PODDef09,          '
	             + 'PODDate01,         '
	             + 'PODDate02,         '
	             + 'PODDate03,         '
	             + 'PODDate04,         '
	             + 'PODDate05,         '
	             + 'TrackCol01,        '
	             + 'TrackCol02,        '
	             + 'TrackCol03,        '
	             + 'TrackCol04,        '
	             + 'TrackCol05,        '
	             + 'TrackDate01,       '
	             + 'TrackDate02,       '
	             + 'TrackDate03,       '
	             + 'TrackDate04,       '
	             + 'TrackDate05,       '
	             + 'AddWho,            '
	             + 'AddDate,           '
--	             + 'EditWho,           '
--	             + 'EditDate,          '
	             + 'FinalizeFlag,      '
	             + 'Storerkey,         '
	             + 'SpecialHandling,   '
	             + 'Latitude,          '
	             + 'Longtitude         '
               + ')'
               + ' SELECT '
               + 'Mbolkey,           '
	             + 'Mbollinenumber,    '
	             + 'LoadKey,           '
	             + 'ExternLoadKey,     '               --(Wan01)
	             + 'OrderKey,          '
	             + 'BuyerPO,           '
	             + 'ExternOrderKey,    '
	             + 'InvoiceNo,         '
	             + '[Status],          '
	             + 'ActualDeliveryDate,'
	             + 'InvDespatchDate,   '
	             + 'PodReceivedDate,   '
	             + 'PodFiledDate,      '
	             + 'InvCancelDate,     '
	             + 'RedeliveryDate,    '
	             + 'RedeliveryCount,   '
	             + 'FullRejectDate,    '
	             + 'ReturnRefNo,       '
	             + 'PartialRejectDate, '
	             + 'RejectReasonCode,  '
	             + 'PoisonFormDate,    '
	             + 'PoisonFormNo,      '
	             + 'ChequeNo,          '
	             + 'ChequeAmount,      '
	             + 'ChequeDate,        '
	             + 'Notes,             '
	             + 'Notes2,            '
	             + 'PODDef01,          '
	             + 'PODDef02,          '
	             + 'PODDef03,          '
	             + 'PODDef04,          '
	             + 'PODDef05,          '
	             + 'PODDef06,          '
	             + 'PODDef07,          '
	             + 'PODDef08,          '
	             + 'PODDef09,          '
	             + 'PODDate01,         '
	             + 'PODDate02,         '
	             + 'PODDate03,         '
	             + 'PODDate04,         '
	             + 'PODDate05,         '
	             + 'TrackCol01,        '
	             + 'TrackCol02,        '
	             + 'TrackCol03,        '
	             + 'TrackCol04,        '
	             + 'TrackCol05,        '
	             + 'TrackDate01,       '
	             + 'TrackDate02,       '
	             + 'TrackDate03,       '
	             + 'TrackDate04,       '
	             + 'TrackDate05,       '
	             + 'AddWho,            '
	             + 'AddDate,           '
--	             + 'EditWho,           '
--	             + 'EditDate,          '
	             + 'FinalizeFlag,      '
	             + 'Storerkey,         '
	             + 'SpecialHandling,   '
	             + 'Latitude,          '
	             + 'Longtitude         '
               + ' FROM ' + @c_ArchiveDB + '.dbo.POD WITH (NOLOCK)'
               + ' WHERE Orderkey = @c_Orderkey '

      EXEC sp_executesql @c_ExecSQL,
            N'@c_Orderkey NVARCHAR(10)', 
            @c_Orderkey
      
      IF @@ERROR <> 0 
      BEGIN
         SET @n_Continue = 3
         GOTO NEXT_ORDER
      END 

      SET @c_ExecSQL=N'DELETE FROM ' + @c_ArchiveDB + '.dbo.POD WITH (ROWLOCK)'
                    +' WHERE Orderkey = @c_Orderkey '

      EXEC sp_executesql @c_ExecSQL,
            N'@c_Orderkey NVARCHAR(10)', 
            @c_Orderkey

      IF @@ERROR <> 0 
      BEGIN
         SET @n_Continue = 3
         GOTO NEXT_ORDER
      END 

      COMMIT TRAN

      NEXT_ORDER:

      IF @n_Continue=3 
      BEGIN
         ROLLBACK TRAN
      END
      
      FETCH NEXT FROM CUR_POD INTO @c_Orderkey
   END

   CLOSE CUR_POD
   DEALLOCATE CUR_POD

QUIT_SP:

   IF CURSOR_STATUS( 'GLOBAL', 'CUR_POD') in (0 , 1)  
   BEGIN
      CLOSE CUR_POD
      DEALLOCATE CUR_POD
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

   IF @n_Continue=3  -- Error Occured - Process AND Return
	 BEGIN
	    SELECT @b_Success = 0
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'isp_POD_GetFromArch'		
	    RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
	    RETURN
	 END
	 ELSE
	 BEGIN
	    SELECT @b_Success = 1
	    WHILE @@TRANCOUNT > @n_StartTCnt
	    BEGIN
	    	COMMIT TRAN
	    END
	    RETURN
	 END     
END -- procedure

GO
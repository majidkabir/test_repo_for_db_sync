SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp0000P_WSIML_GENERIC_WMSPushToQcmdbyClass        */
/* Creation Date: 30-Mar-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: KHChan                                                   */
/*                                                                      */
/* Purpose: Submitting task to Q commander                              */    
/*                                                                      */    
/*                                                                      */    
/* Called By: Schedule Job                                              */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 1.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver.  Purposes												*/
/* 13-Apr-2022 KHChan   1.0   Handle SKU (KH01)                         */
/************************************************************************/

CREATE PROC [dbo].[isp0000P_WSIML_GENERIC_WMSPushToQcmdbyClass] (
      @c_QCmdClass               NVARCHAR(10)
     , @b_Debug                  INT
     , @b_Success                INT             = 0  OUTPUT
     , @n_Err                    INT             = 0  OUTPUT
     , @c_ErrMsg                 NVARCHAR(250)   = '' OUTPUT
     )

AS 
BEGIN 
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF     


   DECLARE @c_FrmTransmitlogKey              NVARCHAR(10)
         , @c_ToTransmitlogKey               NVARCHAR(10)
         , @n_Exists                         INT
         , @n_RowRefNo                       INT
         , @c_TableName                      NVARCHAR(20)
         , @c_DataStream                     NVARCHAR(10)
         , @c_StorerKey                      NVARCHAR(15)

   SET @c_FrmTransmitlogKey                  = ''
   SET @c_ToTransmitlogKey                   = ''
   SET @n_Exists                             = 0
   SET @n_RowRefNo                           = 0
   SET @c_TableName                          = ''
   SET @c_DataStream                         = ''
   SET @c_StorerKey                          = ''


   IF @c_QCmdClass NOT LIKE 'PTQ%'
      GOTO QUIT
   
   IF CURSOR_STATUS('LOCAL' , 'C_QcmdTmlCfg') in (0 , 1)
	BEGIN
		CLOSE C_QcmdTmlCfg 
		DEALLOCATE C_QcmdTmlCfg 
	END 

   DECLARE C_QcmdTmlCfg CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RowRefNo
   FROM Qcmd_TransmitlogConfig WITH (NOLOCK)
   WHERE PhysicalTableName = 'TRANSMITLOG2'
   AND QCmdClass = @c_QCmdClass
   ORDER BY RowRefNo

   OPEN C_QcmdTmlCfg  
   FETCH NEXT FROM C_QcmdTmlCfg INTO @n_RowRefNo
   WHILE @@FETCH_STATUS <> -1   
   BEGIN
		IF @b_Debug = 1
      BEGIN
         PRINT '[isp0000P_WSIML_GENERIC_WMSPushToQcmdbyClass]: @n_RowRefNo=' + CAST(CAST(@n_RowRefNo AS INT)AS NVARCHAR)
      END

      SET @c_TableName = ''
      SET @c_DataStream = ''
      SET @c_StorerKey = ''

      SELECT @c_TableName = ISNULL(TRIM(TableName),'')
         ,@c_DataStream = ISNULL(TRIM(DataStream),'')
         ,@c_StorerKey = ISNULL(TRIM(StorerKey),'')
      FROM Qcmd_TransmitlogConfig WITH (NOLOCK)
      WHERE RowRefNo = @n_RowRefNo

      SET @n_Exists = 0
      SELECT TOP 1 @n_Exists = (1) 
      FROM TCPSocket_QueueTask WITH (NOLOCK) 
      WHERE DataStream = @c_DataStream 
      AND Status IN ('0', '1') 

      IF @n_Exists = 0
      BEGIN
         SET @c_FrmTransmitlogKey = ''
         SET @c_ToTransmitlogKey = ''

         SELECT TOP 1 @c_FrmTransmitlogKey = ISNULL(TRIM(TransmitLogKey),'')
               ,@c_ToTransmitlogKey = ISNULL(TRIM(TransmitLogKey),'')
         FROM TRANSMITLOG2 WITH (NOLOCK)
         WHERE Tablename = @c_TableName
         AND TransmitFlag IN ('0', '1')
         --AND Key3 = @c_StorerKey --(KH01)
         AND (Key3 = @c_StorerKey OR Key1 = @c_StorerKey)--(KH01)
         ORDER BY TransmitLogKey DESC

         EXEC isp_QCmd_WSTransmitLogInsertAlert @c_QCmdClass = @c_QCmdClass
         , @c_FrmTransmitlogKey = @c_FrmTransmitlogKey
         , @c_ToTransmitlogKey = @c_ToTransmitlogKey
         , @b_Debug = @b_Debug, @b_Success = @b_Success, @n_Err = @n_Err, @c_ErrMsg = @c_ErrMsg  

      END --IF @n_Exists = 0

		FETCH NEXT FROM C_QcmdTmlCfg INTO @n_RowRefNo
   END -- WHILE @@FETCH_STATUS <> -1   
   CLOSE C_QcmdTmlCfg  
   DEALLOCATE C_QcmdTmlCfg


   QUIT:
END -- End Procedure


GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Copyright: IDS                                                             */
/* Purpose: BondDPC Integration SP                                            */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2013-02-15 1.0  Shong      Created                                         */
/* 2013-12-20 1.1  ChewKP     Enhancement (ChewKP02)                          */
/* 2014-02-05 1.2  James      SOS296464 - Add Cart type (james01)             */
/* 2014-04-01 1.3  James      Ignore invalid socket msg (james02)             */
/*                            Not update remark in ptltran if already hv value*/
/* 2014-04-15 1.4  Chee       Set @c_Remarks as ErrMsg to show on TCPSocket   */
/*                            Listener Log (Chee01)                           */
/* 2014-05-22 1.5  Shong      Do no reprocess if status = 9                   */
/* 2014-09-02 1.6  ChewKP     Unity Enhancement (ChewKP03)                    */
/* 2014-11-24 1.7  Ung        SOS316714 Change to control by sub SP           */
/******************************************************************************/

CREATE  PROC [dbo].[isp_DPC_Inbound]
     @n_SerialNo  INT
    ,@b_Debug     INT
    ,@b_Success   INT OUTPUT
    ,@n_Err       INT OUTPUT
    ,@c_ErrMsg    NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON

   IF EXISTS(SELECT 1 FROM TCPSocket_INLog ti (NOLOCK)
             WHERE ti.SerialNo=@n_SerialNo
             AND   ti.STATUS = '9')
   BEGIN
      RETURN
   END

   DECLARE @c_Delim       CHAR(5)
          ,@c_InMessage   VARCHAR(4000)
          ,@n_PTLKey      BIGINT
          ,@c_IPAddress   VARCHAR(40)
          ,@c_LightLoc    VARCHAR(20)
          ,@c_QtyReturn   VARCHAR(5)
          ,@c_Condition   VARCHAR(20)
          ,@c_MessageNum  VARCHAR(10)
          ,@n_ActualQty   INT
          ,@c_Status      VARCHAR(2)
          ,@c_Remarks     VARCHAR(200)
          ,@c_DeviceType  NVARCHAR(20) -- (ChewKP01)
          ,@c_DeviceProfileKey     NVARCHAR(10) -- (ChewKP01)
          ,@c_DeviceProfileLogKey  NVARCHAR(10) -- (ChewKP01)
          ,@c_SKU                  NVARCHAR(20) -- (ChewKP01)
          ,@c_StorerKey            NVARCHAR(15) -- (ChewKP01)
          ,@c_StoredProcName       NVARCHAR(50) -- (ChewKP01)
          ,@c_AlertMessage         NVARCHAR( 255) -- (ChewKP01)
          ,@c_ModuleName           NVARCHAR( 45)  -- (ChewKP01)
          ,@bSuccess               INT            -- (ChewKP01)
          ,@c_Parms                NVARCHAR(4000) -- (ChewKP01)
          ,@cSQLParam              NVARCHAR(4000) -- (ChewKP01)
          ,@c_SQL                  NVARCHAR(4000) -- (ChewKP01)
          ,@c_DropID               NVARCHAR(20)   -- (ChewKP01)
          ,@n_Qty                  INT            -- (ChewKP01)
          ,@c_DeviceID             NVARCHAR( 20)  -- (james01)
          ,@n_ErrNo                INT            -- (james01)
          ,@c_Trace                NVARCHAR( 1)   -- (ChewKP01)
          ,@c_GETPTLKeySP          NVARCHAR(30)   -- (ChewKP01)
          ,@cSQL                   NVARCHAR(1000)-- (ChewKP01)


   SET @c_Remarks=''
   SET @c_Status = '9'
   SELECT @c_InMessage = ti.[Data]
   FROM TCPSocket_INLog ti WITH (NOLOCK)
   WHERE ti.SerialNo = @n_SerialNo

   DECLARE @t_DPCRec TABLE (
      Seqno    INT,
      ColValue VARCHAR(215)
   )

   SET @c_Delim = '<TAB>'
   SET @c_DeviceType = ''
   SET @c_DeviceProfileKey = ''
   SET @c_DeviceProfileLogKey = ''
   SET @c_SKU = ''
   SET @n_Qty = 0
   SET @c_Trace = '0'
   SET @n_PTLKey = 0
   SET @c_StoredProcName = ''

   INSERT INTO @t_DPCRec
   SELECT * FROM dbo.fnc_DelimSplit(@c_Delim, @c_InMessage)

   UPDATE @t_DPCRec
   SET ColValue = REPLACE ( ColValue, 'TAB>', '')

   --2  3          4         5              6    7      8
   --53 0000000025 RECV_DATA 172.26.204.205 0201 NORMAL 00005
   SELECT @c_MessageNum = ColValue
   FROM @t_DPCRec
   WHERE Seqno = 3

   SELECT @c_IPAddress = ColValue
   FROM @t_DPCRec
   WHERE Seqno = 5

   SELECT @c_LightLoc = ColValue
   FROM @t_DPCRec
   WHERE Seqno = 6

   SELECT @c_Condition = ColValue
   FROM @t_DPCRec
   WHERE Seqno = 7

   SELECT @c_QtyReturn = ColValue
   FROM @t_DPCRec
   WHERE Seqno = 8

   -- (james02)
   IF ISNULL( @c_QtyReturn, '') = ''
   BEGIN
      UPDATE TCPSocket_INLog WITH (ROWLOCK)
      SET STATUS = '9', EditDate = GETDATE()
      WHERE SerialNo = @n_SerialNo

      GOTO Quit
   END

   -- (ChewKP02)
   IF EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)
             WHERE IPAddress = @c_IPAddress
               AND DevicePosition = @c_LightLoc
               AND DeviceType = 'LOC' )
   BEGIN
      SET @c_DeviceType = 'LOC'

      SELECT @c_DeviceProfileLogKey = DeviceProfileLogKey
            ,@c_DeviceProfileKey    = DeviceProfileKey
      FROM dbo.DeviceProfile WITH (NOLOCK)
      WHERE IPAddress = @c_IPAddress
      AND DevicePosition = @c_LightLoc
      AND DeviceType = @c_DeviceType
   END

   -- (james01)
   IF EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)
               WHERE IPAddress = @c_IPAddress
               AND DevicePosition = @c_LightLoc
               AND DeviceType = 'CART' )
   BEGIN
      SET @c_DeviceType = 'CART'

      SELECT @c_DeviceProfileLogKey = DeviceProfileLogKey
            ,@c_DeviceProfileKey    = DeviceProfileKey
      FROM dbo.DeviceProfile WITH (NOLOCK)
      WHERE IPAddress = @c_IPAddress
      AND DevicePosition = @c_LightLoc
      AND DeviceType = @c_DeviceType
   END

   -- Get Storer
   SELECT TOP 1 @c_StorerKey = StorerKey
   FROM PTLTran WITH (NOLOCK)
   WHERE IPAddress = @c_IPAddress
      AND DevicePosition = @c_LightLoc
      AND Status = '1'

   -- Get TCPProcess stored procedure
   SELECT @c_StoredProcName = RTRIM( ISNULL( SProcName, ''))
   FROM dbo.TCPSocket_Process WITH (NOLOCK)
   WHERE StorerKey = @c_StorerKey
      AND MessageName = @c_DeviceType

   -- Check SP valid
   IF @c_StoredProcName <> ''
      IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID( @c_StoredProcName) AND type in ('P', 'PC'))
         SET @c_StoredProcName = ''
         
   -- Execute custom stored procedure
   IF @c_StoredProcName <> ''
   BEGIN
      SET @c_SQL  = 'EXEC ' + @c_StoredProcName + 
         ' @c_MessageNum, @c_IPAddress, @c_LightLoc, @c_Condition, @c_QtyReturn, @c_StorerKey, @c_DeviceProfileLogKey, @n_Err OUTPUT, @c_ErrMsg OUTPUT '
      SET @cSQLParam = 
         '@c_MessageNum          NVARCHAR(10),  ' + 
         '@c_IPAddress           NVARCHAR(40),  ' + 
         '@c_LightLoc            NVARCHAR(20),  ' + 
         '@c_Condition           NVARCHAR(20),  ' + 
         '@c_QtyReturn           NVARCHAR(5),   ' + 
         '@c_StorerKey           NVARCHAR(15),  ' + 
         '@c_DeviceProfileLogKey NVARCHAR(10),  ' + 
         '@n_Err                 INT           OUTPUT, ' + 
         '@c_ErrMsg              NVARCHAR(255) OUTPUT  '

      EXEC sp_ExecuteSQL @c_SQL ,@cSQLParam
         ,@c_MessageNum
         ,@c_IPAddress
         ,@c_LightLoc 
         ,@c_Condition
         ,@c_QtyReturn
         ,@c_StorerKey
         ,@c_DeviceProfileLogKey
         ,@n_Err        OUTPUT
         ,@c_ErrMsg     OUTPUT
   END
   ELSE
   BEGIN
      IF ISNUMERIC(@c_QtyReturn) = 1
      BEGIN
         IF @c_Condition = 'SHORTAGE'
         BEGIN
            SET @n_ActualQty = CAST(@c_QtyReturn AS INT)  -- (ChewKP01)
            SET @c_Remarks='Shortage'
         END        
         ELSE    
         BEGIN    
            SET @n_ActualQty = @c_QtyReturn    
         END    
      END          
      ELSE           
      BEGIN          
         -- (ChewKP01) 
         IF ISNULL(LTRIM(@c_QtyReturn),'')  IN ( 'FTOTE', 'FULL', 'HOLD', 'END' ) 
         BEGIN          
            SET @c_Remarks = ''          
         END          
         ELSE IF ISNUMERIC(RIGHT(@c_QtyReturn , 3)) = 1
         BEGIN
            SET @n_ActualQty = RIGHT(@c_QtyReturn , 3)     
         END
         ELSE        
         BEGIN          
            SET @n_ActualQty = 0
            SET @c_Status = '5'
            SET @c_Remarks = 'Invalid Qty'
         END
      END
   
      IF @b_Debug=1
      BEGIN
         SELECT @c_IPAddress '@c_IPAddress', @c_LightLoc '@c_LightLoc', @n_ActualQty '@n_ActualQty'
      END

      -- Get storer config
      EXEC nspGetRight
           @c_Facility  = NULL,
           @c_StorerKey = @c_StorerKey,
           @c_sku       = NULL,
           @c_ConfigKey = 'GetPTLKeySP',
           @b_Success   = @b_Success                      OUTPUT,
           @c_authority = @c_GETPTLKeySP                  OUTPUT,
           @n_err       = @n_err                          OUTPUT,
           @c_errmsg    = @c_errmsg                       OUTPUT
   
      IF ISNULL(RTRIM(@c_GETPTLKeySP),'') <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @c_GETPTLKeySP AND type = 'P')
         BEGIN
               SET @cSQL = 'EXEC dbo.' + RTRIM( @c_GETPTLKeySP) +
                  ' @c_IPAddress, @c_LightLoc, @c_QtyReturn, @n_PTLKey OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '
   
               SET @cSQLParam =
                  '@c_IPAddress     VARCHAR(40),      ' +
                  '@c_LightLoc      VARCHAR(20),      ' +
                  '@c_QtyReturn     VARCHAR(5),       ' +
                  '@n_PTLKey        INT OUTPUT,              ' +
                  '@n_Err      INT           OUTPUT,  ' +
                  '@c_ErrMsg     NVARCHAR( 20) OUTPUT '
   
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                   @c_IPAddress, @c_LightLoc, @c_QtyReturn, @n_PTLKey OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT
   
               SELECT TOP 1 --@n_PTLKey    = PTLKey
                     @c_StorerKey = StorerKey -- (ChewKP01)
                     ,@c_DropID    = DropID -- (ChewKP01)
                     ,@c_DeviceID  = DeviceID -- (james01)
               FROM PTLTran p WITH (NOLOCK)
               WHERE PTLKey = @n_PTLKey
               AND Status = '1'
         END
      END
      ELSE
      BEGIN
         SELECT TOP 1 @n_PTLKey    = PTLKey
                     ,@c_StorerKey = StorerKey -- (ChewKP01)
                     ,@c_DropID    = DropID -- (ChewKP01)
                     ,@c_DeviceID  = DeviceID -- (james01)
         FROM PTLTran p WITH (NOLOCK)
         WHERE p.IPAddress = @c_IPAddress
         AND   p.DevicePosition = @c_LightLoc
         AND   p.[Status] = '1'
      END
   
      IF ISNULL(@n_PTLKey, 0) = 0
      BEGIN
         IF LEN(@c_Remarks) = 0
            SET @c_Remarks =  'Record Not Found'
         INSERT INTO PTLTran
         (
            IPAddress,          DevicePosition,    [Status],
            PTL_Type,           DropID,           OrderKey,
            SKU,                LOC,              ExpectedQty,
            Qty,                Remarks,          MessageNum
         )
         VALUES
         (
            @c_IPAddress, @c_LightLoc, '5',
            'ERROR',      '',          '',
            '',           '',          0,
            @n_ActualQty, @c_Remarks, @c_MessageNum)
      END
      ELSE
      BEGIN
         IF ISNULL(RTRIM(@c_StoredProcName),'') <> ''
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[' + @c_StoredProcName + ']') AND type in (N'P', N'PC'))
            BEGIN
               SELECT @c_ModuleName = 'PTS'
               SET @c_AlertMessage = 'Stored Procedure not Found In Database. SP= ' + LTRIM(RTRIM(@c_StoredProcName))
   
               -- Insert LOG Alert
               SELECT @bSuccess = 1
               EXECUTE dbo.nspLogAlert
                @c_ModuleName   = @c_ModuleName,
                @c_AlertMessage = @c_AlertMessage,
                @n_Severity     = 0,
                @b_success      = @bSuccess OUTPUT,
                @n_err          = @n_Err OUTPUT,
                @c_errmsg       = @c_ErrMsg OUTPUT
            END
            ELSE
            BEGIN
               /* Execute Function and Return the String back to AckData */
   
              -- (ChewKP03)
               SET @c_SQL  = N'EXEC ' +  @c_StoredProcName + ' ' +  N' @n_PTLKey, @c_StorerKey, @c_DeviceProfileLogKey, @c_DropID, @n_ActualQty, @n_Err OUTPUT,@c_ErrMsg OUTPUT, @c_Status OUTPUT, @c_MessageNum'
               SET @cSQLParam = N'@n_PTLKey INT, @c_StorerKey NVARCHAR(15), @c_DeviceProfileLogKey NVARCHAR(20), @c_DropID NVARCHAR(20), @n_ActualQty INT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(255) OUTPUT , @c_Status NVARCHAR(2) OUTPUT,  @c_MessageNum NVARCHAR(10) '
   
               IF @@ERROR <> 0
               BEGIN
                  SET @c_ErrMsg = @c_ErrMsg
               END
   
               EXEC sp_ExecuteSql @c_SQL
                               ,@cSQLParam
                               ,@n_PTLKey
                               ,@c_StorerKey
                               ,@c_DeviceProfileLogKey
                               ,@c_DropID
                               ,@n_ActualQty
                               ,@n_Err        OUTPUT
                               ,@c_ErrMsg   OUTPUT
                               ,@c_Status   OUTPUT -- (ChewKP03)
                               ,@c_MessageNum      -- (ChewKP03)
   
               SET @c_Trace = '1'
            END
         END
   
         IF @c_Condition = 'SHORTAGE'
         BEGIN
            -- Terminate all light
            EXEC [dbo].[isp_DPC_TerminateAllLight]
                @c_StorerKey   = @c_StorerKey
               ,@c_DeviceID    = @c_DeviceID
               ,@b_Success     = @b_Success     OUTPUT
               ,@n_Err         = @n_ErrNo       OUTPUT
               ,@c_ErrMsg      = @c_ErrMsg      OUTPUT
   
            IF @n_ErrNo <> 0
            BEGIN
               UPDATE PTLTRAN WITH (ROWLOCK)
                  SET STATUS  = @c_Status,
                      Remarks = CASE WHEN ISNULL( Remarks, '') <> '' THEN Remarks ELSE @c_Remarks END,   -- (james02)
                      EditDate = GETDATE()
               WHERE  DeviceID = @c_DeviceID
               AND    Status < '9'
   
            END
         END
         ELSE
         BEGIN
            UPDATE PTLTRAN WITH (ROWLOCK)
               SET Qty     = @n_ActualQty,
                   STATUS  = @c_Status,
                   Remarks = CASE WHEN ISNULL( Remarks, '') <> '' THEN Remarks ELSE @c_Remarks END,      -- (james02)
                   MessageNum = @c_MessageNum,
                   EditDate = GETDATE()
            WHERE PTLKey = @n_PTLKey
         END
      END
   
      -- Chee01
      IF @c_Remarks <> '' AND ISNULL(@c_ErrMsg, '') = ''
         SET @c_ErrMsg = @c_Remarks
   END

   UPDATE TCPSocket_INLog WITH (ROWLOCK)  -- (james02)
   SET STATUS = '9', EditDate = GETDATE()
   WHERE SerialNo = @n_SerialNo
   

Quit:

END



GO
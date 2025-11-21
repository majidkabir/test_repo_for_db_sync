SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Stored Proceduew Name: isp_PTL_TerminateModuleSingle                       */
/* Copyright: IDS                                                             */
/* Purpose: BondDPC Integration SP                                            */
/*          This SP is to Terminate All Light By PutawayZone                  */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2018-01-03 1.0  ChewKP     WMS-3487 Created                                */
/* 2019-01-22 1.1  ChewKP     Tuning                                          */
/* 2022-03-22 1.2  yeekung    WMS-18729 add params (Yeekung01)                */
/* 2024-07-30 1.3  yeekung    UWP-22410 Add new Column(yeekung05)					*/
/******************************************************************************/

CREATE   PROC [PTL].[isp_PTL_TerminateModuleSingle]
(
   @c_StorerKey NVARCHAR(15)
  ,@n_Func      INT
  ,@c_DeviceID  NVARCHAR(20)
  ,@c_LightAddress  NVARCHAR(MAX)
  ,@b_Success   INT OUTPUT
  ,@n_Err       INT OUTPUT
  ,@c_ErrMsg    NVARCHAR(215) OUTPUT
  ,@c_DeviceModel     NVARCHAR(20) = 'Light'
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_DeviceIP        NVARCHAR(40),
           @nTranCount        INT,
           @c_PutawayZone     NVARCHAR(10),
           @c_DevicePosition  NVARCHAR(20),
           @c_DeviceType      NVARCHAR(20),
           @c_CurrDeviceID    NVARCHAR(20),
           @c_LightAction     NVARCHAR(20),
           @c_LightCommand    NVARCHAR(2000),
           @c_TCPMessage      NVARCHAR(2000),
           @n_PTLKey          BIGINT,
           @c_PTLType         NVARCHAR(10),
           --@c_LightAddress    NVARCHAR(MAX),
           @n_LightLinkLogKey INT,
			  @cFacility			NVARCHAR(20)



   DECLARE @nStart INT
          ,@nEnd   INT
          ,@cDelimiter CHAR(1)
          ,@cDevicePositionLight NVARCHAR(MAX)

   DECLARE @tSplitOutput TABLE(SplitData NVARCHAR(MAX) )

   SET @c_PutawayZone = ''
   SET @cDelimiter    = ','

   IF @c_DeviceID <> ''
   BEGIN
      SET @c_DeviceIP = ''
      SELECT @c_DeviceIP = ISNULL(ll.IPAddress,'')
            ,@c_DeviceType = ll.DeviceType
				,@cFacility  = Facility
      FROM DeviceProfile ll WITH (NOLOCK)
      WHERE ll.DeviceID = @c_DeviceID

      SET @c_PTLType = @c_DeviceType
   END

	SET @cFacility = CASE WHEN ISNULL(@cFacility,'') = '' THEN '' ELSE @cFacility END

   IF ISNULL(RTRIM(@c_DeviceIP), '') = ''
   BEGIN
      SET @n_Err = 85701
      SET @c_ErrMsg = '85701 Bad DeviceID (not found in DeviceProfile)'
      GOTO Quit
   END




   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN isp_PTL_TerminateModuleSingle -- For rollback or commit only our own transaction

   SET @cDevicePositionLight =  @c_LightAddress

   SET @cDevicePositionLight = REPLACE (@cDevicePositionLight , ',' , ''  )

   IF LEN(@c_LightAddress) > 0
   BEGIN


      SET @c_LightAction ='TerminateModule'
      SET @c_LightCommand = [PTL].fnc_PTL_GenLightCommand(@c_LightAction, '', '',@c_DeviceModel) --(yeekung01)

      INSERT INTO PTL.LFLightLinkLOG(
            Application, LocalEndPoint,   RemoteEndPoint,
            SourceKey,      MessageType,     Data,
            Status,      AddDate,         DeviceIPAddress,Facility)
      VALUES(
            'LFLigthLink', '' , '',
            '0', 'COMMAND', @c_LightCommand + @cDevicePositionLight,
            '0', GetDate(),  @c_DeviceIP, @cFacility )

      SET @n_LightLinkLogKey = @@identity

      UPDATE PTL.LFLightLinkLog WITH (ROWLOCK)
      SET SourceKey = @n_LightLinkLogKey
      WHERE SerialNo = @n_LightLinkLogKey

      --SET @n_LightLinkLogKey = RIGHT((REPLICATE(' ', 7) + CAST(@n_LightLinkLogKey AS VARCHAR(8))), 8)
      SET @c_TCPMessage = @n_LightLinkLogKey

		IF EXISTS (	SELECT 1
						FROM DeviceProfile (NOLOCK)
						WHERE DeviceID = @c_DeviceID
							AND ISNULL(Facility,'') ='')
		BEGIN
    
			--(yeekung01)       
			EXEC PTL.isp_PTL_SendMsg 
				@c_StorerKey = @c_StorerKey, 
				@c_Message  = @c_TCPMessage, 
				@b_success = @b_success OUTPUT, 
				@n_Err     = @n_Err OUTPUT, 
				@c_ErrMsg  = @c_ErrMsg OUTPUT, 
				@c_DeviceType = @c_DeviceType,
				@c_DeviceID = @c_DeviceID,
				@n_Func = @n_Func,
				@cPTSZone = '',
				@cLightcmd = @c_LightCommand

			IF @n_Err <> 0
			BEGIN
				GOTO RollBackTran
			END
		END
      --SET @c_LightAddress = ''
   END





   SELECT @nStart = 1, @nEnd = CHARINDEX(@cDelimiter, @c_LightAddress)
   WHILE @nStart < LEN(@c_LightAddress) + 1
   BEGIN
       IF @nEnd = 0
           SET @nEnd = LEN(@c_LightAddress) + 1


       INSERT INTO @tSplitOutput (SplitData)
       VALUES(SUBSTRING(@c_LightAddress, @nStart, @nEnd - @nStart))
       SET @nStart = @nEnd + 1
       SET @nEnd = CHARINDEX(@cDelimiter, @c_LightAddress, @nStart)

   END

   DECLARE CursorPTLTranLightUp CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT SplitData
   FROM @tSplitOutPut
   Order by SplitData

   OPEN CursorPTLTranLightUp
   FETCH NEXT FROM CursorPTLTranLightUp INTO @c_DevicePosition

   WHILE @@FETCH_STATUS <> -1
   BEGIN

      -- Updating PTL.LightStatus and PTL Tran
      IF NOT EXISTS (SELECT 1 FROM PTL.LightStatus AS ls WITH (NOLOCK)
                     WHERE ls.IPAddress = @c_DeviceIP
                     AND   ls.DevicePosition = @c_DevicePosition
							AND   ls.Facility = @cFacility)
      BEGIN
         INSERT INTO PTL.LightStatus
         (  IPAddress,        DevicePosition,   DeviceID,
            [Status],         PTLKey,           PTLType,
            StorerKey,        UserName,         DisplayValue,
            ReceiveValue,     ReceiveTime,      Remarks,  Func ,
            ErrorMessage,     SourceKey,        DeviceProfileLogKey, LightCmd,Facility )
         VALUES
         (  @c_DeviceIP,      @c_DevicePosition, @c_DeviceID,
            '0',              0,                 @c_PTLType,
            @c_StorerKey,     SUSER_SNAME(),     '',
            '',               NULL,              '',  @n_Func ,
            '',               '',        '', @c_LightCommand, @cFacility)
      END
      ELSE
      BEGIN
         UPDATE PTL.LightStatus WITH (ROWLOCK)
            SET [Status] = '0',
                PTLKey   = 0,
                PTLType  = '',
                StorerKey = @c_StorerKey,
                UserName = SUSER_SNAME(),
                DisplayValue = '',
                ReceiveValue = '',
                ReceiveTime = NULL,
                Remarks = '',
                ErrorMessage = '',
                SourceKey = '' ,
                LightCmd = @c_LightCommand,
                Func = @n_Func
         WHERE IPAddress = @c_DeviceIP
         AND   DevicePosition = @c_DevicePosition
			AND   Facility = @cFacility
      END

      -- Turn off light up flag
      SET @n_PTLKey = 0
      WHILE @n_PTLKey >= 0
      BEGIN
         SELECT @n_PTLKey = PTLKey
         FROM PTL.PTLTran WITH (NOLOCK)
         WHERE IPAddress = @c_DeviceIP
            AND DevicePosition = @c_DevicePosition
            AND LightUp = '1'
         IF @n_PTLKey > 0
         BEGIN
            UPDATE PTL.PTLTran WITH (ROWLOCK)
            SET
               LightUp = '0'
            WHERE PTLKey = @n_PTLKey
            IF @@ERROR <> 0
            BEGIN
               SET @n_Err = 85702
               SET @c_ErrMsg = '85702 UPD PTL Fail'
               GOTO RollBackTran
            END
         END
         ELSE
            BREAK

         SET @n_PTLKey = 0
      END

      FETCH NEXT FROM CursorPTLTranLightUp INTO @c_DevicePosition
   END
   CLOSE CursorPTLTranLightUp
   DEALLOCATE CursorPTLTranLightUp


--   IF LEN(@c_LightAddress) > 0
--   BEGIN
--      SET @c_LightAction ='TerminateModule'
--      SET @c_LightCommand = [PTL].fnc_PTL_GenLightCommand(@c_LightAction, '', '')
--
--      INSERT INTO PTL.LFLightLinkLOG(
--             Application, LocalEndPoint,   RemoteEndPoint,
--             SourceKey,      MessageType,     Data,
--             Status,      AddDate,         DeviceIPAddress )
--      VALUES(
--             'LFLigthLink', '' , '',
--             '0', 'COMMAND', @c_LightCommand + @c_LightAddress,
--             '0', GetDate(), @c_DeviceIP  )
--
--      SET @n_LightLinkLogKey = @@identity
--
--      UPDATE PTL.LFLightLinkLog WITH (ROWLOCK)
--      SET SourceKey = @n_LightLinkLogKey
--      WHERE SerialNo = @n_LightLinkLogKey
--
--      --SET @n_LightLinkLogKey = RIGHT((REPLICATE(' ', 7) + CAST(@n_LightLinkLogKey AS VARCHAR(8))), 8)
--      SET @c_TCPMessage = @n_LightLinkLogKey
--
--      EXEC PTL.isp_PTL_SendMsg @c_StorerKey, @c_TCPMessage, @b_success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT, @c_DeviceType
--                              ,@c_DeviceID
--
--      SET @c_LightAddress = ''
--   END

   COMMIT TRAN isp_PTL_TerminateModuleSingle
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN isp_PTL_TerminateModuleSingle -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END



GO
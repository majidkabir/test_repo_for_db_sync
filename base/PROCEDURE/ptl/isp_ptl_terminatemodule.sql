SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Stored Proceduew Name: isp_PTL_TerminateModule                             */
/* Copyright: IDS                                                             */
/* Purpose: BondDPC Integration SP                                            */
/*          This SP is to Terminate All Light By PutawayZone                  */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2014-02-07 1.0  ChewKP     Created                                         */
/* 2014-05-15 1.1  Shong      Add Deveice ID when calling isp_DPC_SendMsg     */
/* 2015-01-30 1.2  ChewKP     LightUp Update by DevicePosition (CheWKP01)     */
/* 2015-06-25 1.3  ChewKP     Fixes (ChewKP02)                                */
/* 2016-03-21 1.4  Ung        SOS361967 Add DeviceType = STATION              */
/*                            Add back update PTLTran.LightUP = 0             */
/* 2022-03-22 1.5  yeekung    WMS-18729 add params (Yeekung01)                */
/* 2023-11-29 1.6  Yeekung    WMS-23803 add TMS (yeeKung02)                   */
/* 2024-07-30 1.7  yeekung    UWP-22410 Add new Column(yeekung05)					*/
/******************************************************************************/

CREATE    PROC [PTL].[isp_PTL_TerminateModule]
(
   @c_StorerKey NVARCHAR(15)
  ,@n_Func      INT
  ,@c_DeviceID  NVARCHAR(20)
  ,@c_TerminateType NVARCHAR(1)
  ,@b_Success   INT OUTPUT
  ,@n_Err       INT OUTPUT
  ,@c_ErrMsg    NVARCHAR(215) OUTPUT
  ,@c_DeviceModel     NVARCHAR(20) = 'Light'
)
AS
BEGIN
   SET NOCOUNT ON

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
           @c_LightAddress    NVARCHAR(1024),
           @n_LightLinkLogKey INT,
           @cLightCmd         NVARCHAR(2000),
			  @cFacility			NVARCHAR(20)

   SET @c_PutawayZone = ''

   IF @c_DeviceID <> ''
   BEGIN
      SET @c_DeviceIP = ''
      SELECT TOP 1 @c_DeviceIP = ISNULL(ll.IPAddress,'')
            ,@c_DeviceType = ll.DeviceType
				,@cFacility = Facility
      FROM DeviceProfile ll WITH (NOLOCK)
      WHERE ll.DeviceID = @c_DeviceID
      ORDER BY EDITDATE DESC

      SELECT @c_PutawayZone = PutawayZone
      FROM dbo.Loc  WITH (NOLOCK)
      WHERE Loc = @c_DeviceID
   END

	SET @cFacility = 'SCL19'--CASE WHEN ISNULL(@cFacility,'') = '' THEN '' ELSE @cFacility END

   IF  @c_DeviceModel NOT IN ('TMS')  --(yeekung02)
   BEGIN
      IF ISNULL(RTRIM(@c_DeviceIP), '') = ''
      BEGIN
         SET @n_Err = 85701
         SET @c_ErrMsg = '85701 Bad DeviceID (not found in DeviceProfile)'
         GOTO Quit
      END
   END

   IF @c_TerminateType = '0'
   BEGIN
      IF @c_DeviceType = 'LOC'
      BEGIN
         DECLARE CursorPTLTranLightUp CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT D.DevicePosition, D.DeviceType, D.DeviceID
         FROM dbo.DeviceProfile D WITH (NOLOCK)
         INNER JOIN dbo.LOC Loc WITH (NOLOCK) ON Loc.Loc = D.DeviceID
         WHERE D.IPAddress = @c_DeviceIP
         AND Loc.PutawayZone = @c_PutawayZone
         AND D.DeviceType = 'LOC'
      END
      ELSE IF RTRIM(@c_DeviceType) IN ('CART', 'STATION')
      BEGIN
         DECLARE CursorPTLTranLightUp CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT D.DevicePosition, D.DeviceType, D.DeviceID
         FROM dbo.DeviceProfile D WITH (NOLOCK)
         WHERE D.IPAddress = @c_DeviceIP
         AND D.DeviceID = @c_DeviceID
         AND D.DeviceType = @c_DeviceType
      END
   END
   ELSE
   BEGIN
      IF RTRIM(@c_DeviceType) = 'LOC'
      BEGIN
         DECLARE CursorPTLTranLightUp CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT D.DevicePosition, D.DeviceType, D.DeviceID
         FROM dbo.DeviceProfile D WITH (NOLOCK)
         INNER JOIN dbo.LOC Loc WITH (NOLOCK) ON Loc.Loc = D.DeviceID
         WHERE D.IPAddress = @c_DeviceIP
         AND Loc.PutawayZone = @c_PutawayZone
         AND D.DeviceID = @c_DeviceID
         AND D.DeviceType = 'LOC'
      END

      --Terminate ALL Light in CART
      IF RTRIM(@c_DeviceType) IN ('CART', 'STATION')
      BEGIN
         DECLARE CursorPTLTranLightUp CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT  D.DevicePosition, D.DeviceType, D.DeviceID
         FROM dbo.DeviceProfile D WITH (NOLOCK)
         WHERE D.IPAddress = @c_DeviceIP
         AND D.DeviceID = @c_DeviceID
         AND D.DeviceType = @c_DeviceType
      END
   END

   SET @c_LightAddress = ''

   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN isp_PTL_TerminateModule -- For rollback or commit only our own transaction

   OPEN CursorPTLTranLightUp
   FETCH NEXT FROM CursorPTLTranLightUp INTO @c_DevicePosition, @c_DeviceType, @c_CurrDeviceID

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      -- Terminate all lights for CART only
      IF @c_DeviceType IN ('Cart', 'STATION')
      BEGIN
         SET @c_PTLType = @c_DeviceType
      END
      ELSE
      BEGIN
         SET @c_PTLType = 'Pick2PTS'
      END

      SET @c_LightAddress = ISNULL(RTRIM(@c_LightAddress),'') + ISNULL(RTRIM(@c_DevicePosition),'')

      IF LEN(@c_LightAddress) > 500
      BEGIN
         IF @c_DeviceModel IN ('TMS')
         BEGIN
            SELECT top 1 @c_StorerKey=storerkey
            from deviceprofile (nolock)
            where deviceid=@c_DeviceID
            and storerkey<>''

            SELECT @c_LightCommand = [PTL].PTL_GenLightCommand_TMS(@c_DeviceID,@c_DevicePosition,0)

            INSERT INTO PTL.LFLightLinkLOG(
                  Application, LocalEndPoint,   RemoteEndPoint,
                  SourceKey,      MessageType,     Data,
                  Status,      AddDate,         DeviceIPAddress,Facility)
            VALUES(
                  'LFLigthLink', '' , '',
                  '0', 'COMMAND', @c_LightCommand ,
                  '0', GetDate(),  @c_DeviceIP, @cFacility)

            SET @cLightCmd = @c_LightCommand

         END
         ELSE
         BEGIN
            SET @c_LightAction ='TerminateModule'
            SET @c_LightCommand = [PTL].fnc_PTL_GenLightCommand(@c_LightAction, '', '',@c_DeviceModel)

            INSERT INTO PTL.LFLightLinkLOG(
                  Application, LocalEndPoint,   RemoteEndPoint,
                  SourceKey,      MessageType,     Data,
                  Status,      AddDate,         DeviceIPAddress,Facility)
            VALUES(
                  'LFLigthLink', '' , '',
                  '0', 'COMMAND', @c_LightCommand + @c_LightAddress,
                  '0', GetDate(),  @c_DeviceIP, @cFacility )

         END
        
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
					@cLightcmd = @cLightcmd
			END

         SET @c_LightAddress = ''
      END

      IF NOT EXISTS (SELECT 1 FROM PTL.LightStatus AS ls WITH (NOLOCK)
                     WHERE ls.IPAddress = @c_DeviceIP
                     AND   ls.DevicePosition = @c_DevicePosition
							AND   ls.Facility = @cFacility )
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
            '',               '',        '', @c_LightCommand,@cFacility)
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
            UPDATE PTL.PTLTran SET
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

      FETCH NEXT FROM CursorPTLTranLightUp INTO @c_DevicePosition, @c_DeviceType, @c_CurrDeviceID
   END
   CLOSE CursorPTLTranLightUp
   DEALLOCATE CursorPTLTranLightUp

   IF LEN(@c_LightAddress) > 0
   BEGIN
      IF @c_DeviceModel IN ('TMS')
      BEGIN
         SELECT top 1 @c_StorerKey=storerkey
         from deviceprofile (nolock)
         where deviceid=@c_DeviceID
         and storerkey<>''

         SELECT @c_LightCommand = [PTL].PTL_GenLightCommand_TMS(@c_DeviceID,@c_DevicePosition,0)

        INSERT INTO PTL.LFLightLinkLOG(
                Application, LocalEndPoint,   RemoteEndPoint,
                SourceKey,      MessageType,     Data,
                Status,      AddDate,         DeviceIPAddress,Facility )
         VALUES(
                'LFLigthLink', '' , '',
                '0', 'COMMAND', @c_LightCommand ,
                '0', GetDate(), @c_DeviceIP,@cFacility  )

         SET @cLightCmd = @c_LightCommand


      END
      ELSE
      BEGIN
         SET @c_LightAction ='TerminateModule'
         SET @c_LightCommand = [PTL].fnc_PTL_GenLightCommand(@c_LightAction, '', '',@c_DeviceModel)

         INSERT INTO PTL.LFLightLinkLOG(
                Application, LocalEndPoint,   RemoteEndPoint,
                SourceKey,      MessageType,     Data,
                Status,      AddDate,         DeviceIPAddress ,Facility )
         VALUES(
                'LFLigthLink', '' , '',
                '0', 'COMMAND', @c_LightCommand + @c_LightAddress,
                '0', GetDate(), @c_DeviceIP ,@cFacility )

      END

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
				@cLightcmd = @cLightcmd
		END

      SET @c_LightAddress = ''
   END


   COMMIT TRAN isp_PTL_TerminateModule
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN isp_PTL_TerminateModule -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: TouchPadGetMessage                                  */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2023-03-17 1.0  yeekung  Created                                     */
/************************************************************************/

CREATE   FUNCTION [API].[TouchPadGetMessage] (
  @nMsgID   INT, 
  @sLang    NVARCHAR(3) = 'ENG', 
  @sMsgType NVARCHAR(3) = 'DSP' 
) 
RETURNS NVARCHAR(200)
AS
BEGIN
	DECLARE @strout NVARCHAR (200) 

   SELECT @strout = Message_text 
   FROM rdt.rdtmsg WITH (NOLOCK)
   WHERE Message_id = @nMsgID 
      AND Message_type = @sMsgType 
      AND Lang_code = @sLang
   
   IF RTRIM(@strout) IS NULL
   BEGIN
      -- Default Lang Code ENG
      SELECT @strout = Message_text 
      FROM API.TouchPadErrmsg WITH (NOLOCK)
      WHERE Message_id = @nMsgID 
        AND Message_type = @sMsgType 
        AND Lang_code = 'ENG'
   END	
   
   -- All done
   IF RTRIM( @strout) = NULL OR RTRIM( @strout) = ''
      --SET @strout = 'Msg not setup(' + CAST( @nMsgID AS NVARCHAR(5)) + ')'
      SET @strout = 'Msg not setup(' + RIGHT( CAST( @nMsgID AS NVARCHAR(6)), 5) + ')'
         
   RETURN @strout
END

GO
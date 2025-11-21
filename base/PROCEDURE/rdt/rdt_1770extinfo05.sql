SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_1770ExtInfo05                                   */
/* Purpose: Display custom info                                         */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2022-08-10   yeekung   1.0   WMS-20454 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1770ExtInfo05]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@cExtendedInfo1  NVARCHAR( 20) OUTPUT
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
   ,@nAfterStep      INT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPickMethod NVARCHAR(10),
           @cStorerkey  NVARCHAR(20)

   -- Get TaskDetail info
   SELECT @cPickMethod = PickMethod,
            @cStorerkey = storerkey
   FROM TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey

   -- TM Pallet Pick
   IF @nFunc = 1770
   BEGIN

      IF @nAfterStep = 5 -- Next task
      BEGIN
          -- Get LoadKey
         DECLARE @cLoadKey NVARCHAR(10)
         DECLARE @nBookingNo NVARCHAR(10)
         SELECT @cLoadKey = LoadKey
         FROM TaskDetail WITH (NOLOCK) 
         WHERE TaskDetailKey = @cTaskDetailKey

         SELECT @nBookingNo = BookingNo 
         FROM TMS_shipment TS WITH (NOLOCK) 
         JOIN tms_shipmentTransOrderLink TTL (NOLOCK) ON TTL.shipmentgid=TS.shipmentgid
         JOIN tms_transportorder TTO (nolock) ON TTO.ProvshipmentID=TTL.ProvshipmentID
         WHERE TTO.LoadKey = @cLoadKey
         GROUP BY bookingno
         

         IF EXISTS( SELECT 1 from codelkup (nolock)
                    WHERE listname = 'TMEXTNLDKY'
                    AND storerkey=@cstorerkey
                    and short='Y')
         BEGIN
            SELECT @cExtendedInfo1=ExternLoadkey + ' '+ @nBookingNo
            From Loadplan (nolock)
            where loadkey=@cLoadKey
         END
         ELSE
         BEGIN
             SELECT @cExtendedInfo1=loadkey  + ' '+ @nBookingNo
            From Loadplan (nolock)
            where loadkey=@cLoadKey
         END

      END
   END
END

GO
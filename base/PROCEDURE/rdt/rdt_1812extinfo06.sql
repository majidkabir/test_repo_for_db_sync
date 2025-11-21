SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_1812ExtInfo06                                   */
/* Purpose: Extended info                                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2022-08-10   yeekung   1.0   WMS-20454 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1812ExtInfo06]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@cExtendedInfo1  NVARCHAR( 20) OUTPUT
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
   ,@nAfterStep      INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- TM Case Pick
   IF @nFunc = 1812
   BEGIN
      IF @nAfterStep = 6 OR -- TOLOC
         @nAfterStep = 7    -- Close Pallet
      BEGIN
  -- Get LoadKey
         DECLARE @cLoadKey NVARCHAR(10)
         DECLARE @cStorerkey  NVARCHAR(20)
         DECLARE @nBookingNo NVARCHAR(10)

         SELECT @cLoadKey = LoadKey,
               @cStorerkey = storerkey
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
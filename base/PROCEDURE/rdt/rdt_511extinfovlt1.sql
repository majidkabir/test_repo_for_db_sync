SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/****************************************************************************/
/* Store procedure: rdt_511ExtInfoVLT1                                      */
/*                                                                          */
/*                                                                          */
/* Date         VER   Author   Purpose                                      */
/* 25/04/2024   1.0   PPA374   Suggesting up to 2 locations for VNA PA      */
/* 15/07/2024   2.0   PPA374   Stopping picked LPNs to be moved incorrectly */
/****************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_511ExtInfoVLT1] (
@nMobile         INT,
@nFunc           INT,
@cLangCode       NVARCHAR( 3),
@nStep           INT,
@nInputKey       INT,
@cStorerKey      NVARCHAR( 15),
@cFromID         NVARCHAR( 18),
@cFromLOC        NVARCHAR( 10),
@cToLOC          NVARCHAR( 10),
@cToID           NVARCHAR( 18),
@cSKU            NVARCHAR( 20),
@cExtendedInfo   NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 511 and @nStep = 2 and @nInputKey = 1
   BEGIN
      DECLARE 
      @PNDPICKChk int,
      @Facility NVARCHAR(20)

      select top 1 @Facility = FACILITY from rdt.RDTMOBREC (NOLOCK) where Mobile = @nMobile
      set @PNDPICKChk = case when (select top 1 LocationType from loc WITH (NOLOCK) where loc = @cFromLoc and Facility = @Facility and loc like 'B_999%') = 'PND' and exists(select 1 from pickdetail (NOLOCK) where id = @cFromID and sku = @cSKU and status = 5 and dropid <> '' and Storerkey = @cStorerKey) then 1 else 0 end

      IF @PNDPICKChk = 1
      BEGIN
         SET @cExtendedInfo = 'Move to '+
         (select top 1 reverse(substring(reverse(OtherReference),4,10)) from mbol (NOLOCK) where facility = @Facility 
      and mbolkey = (select top 1 mbolkey from orders (NOLOCK) where StorerKey = @cStorerKey and orderkey = 
         (select top 1 OrderKey from pickdetail (NOLOCK) where Storerkey = @cStorerKey and id = @cFromID)))
      END
   END
END

GO
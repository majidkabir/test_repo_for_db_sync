SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: isp_TM_OPK_LOC                                      */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Insert PackDetail after each scan of Case ID                */
/*                                                                      */
/* Called from: rdtfnc_TM_OrderPicking                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 21-May-2010 1.0  ChewKP    Created                                   */
/************************************************************************/

CREATE PROC [dbo].[isp_TM_OPK_LOC] (
   @nMobile              INT,
   @c_FromLoc            NVARCHAR(10),
   @cTaskDetailKey       NVARCHAR(10),
   @cLoadKey             NVARCHAR(10),
	@c_ID						 NVARCHAR(18),
   @cToLOC               NVARCHAR(10)   OUTPUT,
	@cNMVTask				 NVARCHAR(1)     OUTPUT

   --@nErrNo               INT          OUTPUT,
   --@cErrMsg              NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max
) AS
BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE
      @b_success         INT,
      @n_err             INT,
      @c_errmsg          NVARCHAR( 255)

   DECLARE
      @cpa_PutAwayZone01    NVARCHAR(10),
		@cpa_PutAwayZone02    NVARCHAR(10),
		@cpa_PutAwayZone03    NVARCHAR(10),
		@cpa_PutAwayZone04    NVARCHAR(10),
		@cpa_PutAwayZone05    NVARCHAR(10),
		@c_PutawayStrategyKey NVARCHAR(10),
		@c_MaxAisle           NVARCHAR(10), 
		@c_Facility           NVARCHAR(5),	-- CDC Migration
		@c_LastAisle          NVARCHAR(10),
		@c_PnDLocation        NVARCHAR(10),
 		@c_PnDAisle		       NVARCHAR(10),
		@c_LastPndAisle		 NVARCHAR(10),
		@c_PnDLocCat          NVARCHAR(10),  -- (SHONG02)
		@cpa_AreaKey          NVARCHAR(10),
		@cErrMSG					 NVARCHAR(20)


	   

   DECLARE    @n_debug		int

   SET @n_debug = 0

	SET @cNMVTask = '0'
   
   SELECT @c_Facility = Facility
   FROM   LOC WITH (NOLOCK)
   WHERE  Loc = @c_FromLoc
   
   SELECT TOP 1 
         @c_PutawayStrategyKey = STRATEGY.PutAwayStrategyKey
    FROM   STRATEGY WITH (NOLOCK)
           JOIN SKU WITH (NOLOCK) ON  SKU.STRATEGYKEY = STRATEGY.Strategykey
           JOIN LOTxLOCxID lli WITH (NOLOCK) ON (lli.StorerKey = sku.StorerKey AND lli.Sku = SKU.Sku)
    WHERE  lli.Loc = @c_FromLoc 
			AND lli.Id = @c_ID       
			AND lli.Qty > 0 
    ORDER BY lli.Qty DESC
	
	SELECT TOP 1 @cpa_PutAwayZone01     = PutAwayZone01,
           @cpa_PutAwayZone02     = PutAwayZone02, 
           @cpa_PutAwayZone03     = PutAwayZone03, 
           @cpa_PutAwayZone04     = PutAwayZone04, 
           @cpa_PutAwayZone05     = PutAwayZone05 
    FROM   PUTAWAYSTRATEGYDETAIL WITH (NOLOCK)
    WHERE  PutAwayStrategyKey = @c_PutawayStrategyKey
    
           
   
    
   
   -- Get Current Aisle from TaskDetail FromLoc                    
   SELECT TOP 1 
          @c_LastAisle = L.LocAisle,
			 @cpa_AreaKey = AD.Areakey
   FROM   TaskDetail td WITH (NOLOCK)
          JOIN LOC L WITH (NOLOCK)  ON  L.LOC = td.FromLoc
	 INNER JOIN	AREADETAIL AD WITH (NOLOCK) ON AD.Putawayzone = L.Putawayzone	 
                   --AND L.LocationCategory IN ('PnD_Ctr' ,'PnD_Out')
          --JOIN @t_ZoneAisle ZoneAisle
               --ON  ZoneAisle.LocAisle = L.LocAisle
   WHERE  L.Facility = @c_Facility
          AND td.TaskDetailkey = @cTaskDetailKey
   ORDER BY
          TaskDetailKey DESC 
          
   -- 1st try, Get avaible P&D Loc within same ailse (Start) --
   SET @c_PnDLocation = ''
   SET @c_PnDAisle = ''
   SET @c_PnDLocCat = ''
   
    SELECT TOP 1 
           @c_PnDLocation = L.LOC
          ,@c_PnDAisle = L.LocAisle
          ,@c_PnDLocCat = L.LocationCategory 
    FROM   LOC L WITH (NOLOCK)
           --JOIN @t_ZoneAisle ZoneAisle
           --     ON  ZoneAisle.LocAisle = L.LocAisle
           LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK)
                ON  LLI.Loc = L.Loc
    WHERE  L.LocationCategory IN ('PnD_Ctr' ,'PnD_Out')
           AND L.Facility = @c_Facility
           AND L.LocAisle=  @c_LastAisle
    GROUP BY
           L.LOC
          ,L.LogicalLocation
          ,L.LocAisle
          ,L.LocationCategory 
    HAVING SUM(ISNULL(LLI.Qty ,0)+ISNULL(LLI.PendingMoveIN ,0))=0
    ORDER BY
           L.LocAisle
          ,L.LogicalLocation
          ,L.LOC
   
	SET @cToLoc = @c_PnDLocation

   IF ISNULL(RTRIM(@c_PnDLocation),'') <> ''
   BEGIN
       GOTO QUIT
   END

   

   -- 1st try, Get avaible P&D Loc within same ailse (End) --
   
   -- 2nd try, Get avaible P&D Loc within same Area (Start) --
   
   -- Get Aisle from Same Area --
   SET @c_PnDLocation = ''
   SET @c_PnDAisle = ''
   SET @c_PnDLocCat = ''
   
   DECLARE @t_ZoneAisle TABLE (LocAisle NVARCHAR(10))
    
   INSERT INTO @t_ZoneAisle        
   SELECT DISTINCT LOC.LocAisle 
   FROM   LOC LOC WITH (NOLOCK)
   INNER JOIN AREADETAIL AD (NOLOCK) ON AD.Putawayzone = LOC.Putawayzone
   WHERE  LOC.PutawayZone IN (@cpa_PutAwayZone01
                             ,@cpa_PutAwayZone02
                             ,@cpa_PutAwayZone03
                             ,@cpa_PutAwayZone04
                             ,@cpa_PutAwayZone05 )
   AND LOC.PutawayZone IS NOT NULL
   AND AD.Areakey = @cpa_AreaKey
   
   SELECT TOP 1 
           @c_PnDLocation = L.LOC
          ,@c_PnDAisle = L.LocAisle
          ,@c_PnDLocCat = L.LocationCategory 
    FROM   LOC L WITH (NOLOCK)
           JOIN @t_ZoneAisle ZoneAisle
                ON  ZoneAisle.LocAisle = L.LocAisle
           LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK)
                ON  LLI.Loc = L.Loc
			  ----INNER JOIN t_ZoneAisle ZoneAisle
             --   ON  ZoneAisle.LocAisle = L.LocAisle
    WHERE  L.LocationCategory IN ('PnD_Ctr' ,'PnD_Out')
           AND L.Facility = @c_Facility
           
    GROUP BY
           L.LOC
          ,L.LogicalLocation
          ,L.LocAisle
          ,L.LocationCategory 
    HAVING SUM(ISNULL(LLI.Qty ,0)+ISNULL(LLI.PendingMoveIN ,0))=0
    ORDER BY
           L.LocAisle
          ,L.LogicalLocation
          ,L.LOC   
   
	SET @cToLoc = @c_PnDLocation

   IF ISNULL(RTRIM(@c_PnDLocation),'') <> ''
   BEGIN
       GOTO QUIT
   END
   
   -- 2nd try, Get avaible P&D Loc within same Area (End) --
   
   
   -- 3rd try, Direct to Sent to HVCP Lane (Start) --
   -- No NMV Task Required --
   SELECT TOP 1 @cToLoc = Loc FROM LoadPlanLaneDetail LLD (NOLOCK)
   WHERE LocationCategory = 'HVCP' 
   AND Loadkey = @cLoadKey 
   
   SET @cNMVTask = '1'
   GOTO QUIT
   -- 3rd try, Direct to Sent to HVCP Lane (End) --
   
   QUIT:
   
   
END

GO
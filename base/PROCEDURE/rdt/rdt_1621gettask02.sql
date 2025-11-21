SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_1621GETTASK02                                   */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Use Codelkup to determine pick seq                          */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 2021-06-28  1.0  James       WMS-17350. Created                      */  
/* 2023-04-18  1.1  James       WMS-22196 Add new sorting logic(james01)*/
/************************************************************************/  

CREATE   PROC [RDT].[rdt_1621GETTASK02] (  
   @n_Mobile                  INT, 
   @n_Func                    INT, 
   @c_StorerKey               NVARCHAR( 15),  
   @c_UserName                NVARCHAR( 15),  
   @c_Facility                NVARCHAR( 5),  
   @c_PutAwayZone             NVARCHAR( 10),  
   @c_PickZone                NVARCHAR( 10),  
   @c_LangCode                NVARCHAR( 3),  
	@c_oFieled01               NVARCHAR( 20)      OUTPUT,
	@c_oFieled02               NVARCHAR( 20)      OUTPUT,
   @c_oFieled03               NVARCHAR( 20)      OUTPUT,
   @c_oFieled04               NVARCHAR( 20)      OUTPUT,
   @c_oFieled05               NVARCHAR( 20)      OUTPUT,
   @c_oFieled06               NVARCHAR( 20)      OUTPUT,
   @c_oFieled07               NVARCHAR( 20)      OUTPUT,
   @c_oFieled08               NVARCHAR( 20)      OUTPUT,
   @c_oFieled09               NVARCHAR( 20)      OUTPUT,
   @c_oFieled10               NVARCHAR( 20)      OUTPUT,
	@c_oFieled11               NVARCHAR( 20)      OUTPUT,
	@c_oFieled12               NVARCHAR( 20)      OUTPUT,
   @c_oFieled13               NVARCHAR( 20)      OUTPUT,
   @c_oFieled14               NVARCHAR( 20)      OUTPUT,
   @c_oFieled15               NVARCHAR( 20)      OUTPUT, 
   @b_Success                 INT            OUTPUT, 
   @nErrNo                    INT            OUTPUT,   
   @cErrMsg                   NVARCHAR( 20)   OUTPUT 
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @c_LoadKey      NVARCHAR( 10) = '',
           @n_PickBySeq    INT = 0
   
   DECLARE @c_LocAisle      NVARCHAR( 10) = ''
   DECLARE @c_ItemClass     NVARCHAR( 10) = ''
   DECLARE @c_LocBay        NVARCHAR( 10) = ''
   DECLARE @c_Busr6         NVARCHAR( 10) = ''
   DECLARE @c_LastSKU       NVARCHAR( 20) = ''
   DECLARE @n_PD_Qty        INT = 0
   DECLARE @n_Debug         INT = 0
   DECLARE @n_SkipSearch    INT = 0
   DECLARE @curHighestMat   CURSOR

   DECLARE @t TABLE ( ItemClass NVARCHAR( 10), Cnt INT)
      
   SELECT @c_LoadKey    = V_LoadKey,
          @c_UserName   = UserName
   FROM rdt.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @n_Mobile

   SELECT @n_PickBySeq = 1
   FROM dbo.CODELKUP CL WITH (NOLOCK)
   WHERE CL.LISTNAME = 'NIKESORT'
   AND   CL.Storerkey = @c_StorerKey
   AND   EXISTS ( SELECT 1 FROM dbo.ORDERS O WITH (NOLOCK) 
                  JOIN RDT.RDTPickLock RPL WITH (NOLOCK) ON ( RPL.StorerKey = O.StorerKey AND RPL.OrderKey = O.OrderKey)
                  WHERE CL.Storerkey = O.StorerKey 
                  AND   CL.Code = O.ConsigneeKey 
                  AND   O.LoadKey = @c_LoadKey
                  AND   RPL.StorerKey = @c_StorerKey
                  AND   RPL.Status < '9'
                  AND   RPL.AddWho = @c_UserName) 
   --SET @n_PickBySeq = 1
   
   IF @n_PickBySeq = 1
   BEGIN
   	-- Check last picked sku.itemclass (material)
   	SELECT TOP 1 @c_LastSKU = SKU
   	FROM rdt.rdtPickLock WITH (NOLOCK)
   	WHERE LoadKey = @c_LoadKey
   	AND   AddWho = @c_UserName
   	AND   [Status] = '5'
   	ORDER BY RowRef DESC
   	
   	IF @c_LastSKU <> ''
   	BEGIN
   		SELECT @c_ItemClass = itemclass
   		FROM dbo.SKU WITH (NOLOCK)
   		WHERE StorerKey = @c_StorerKey
   		AND   Sku = @c_LastSKU
   		
         -- Continue from last itemclass and look for smallest size (SKU.Busr6)
         SELECT TOP 1
            @c_Busr6 = SKU.BUSR6
         FROM RDT.RDTPickLock RPL WITH (NOLOCK)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
         WHERE RPL.StorerKey = @c_StorerKey
            AND RPL.Status < '9'
            AND RPL.AddWho = @c_UserName
            AND PD.Status = '0'
            AND (( ISNULL( @c_PutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @c_PutAwayZone))
            AND (( ISNULL(@c_PickZone, '') = '') OR ( L.PickZone = @c_PickZone))
            AND L.Facility = @c_Facility
            AND SKU.itemclass = @c_ItemClass
            AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL WITH (NOLOCK)
                              WHERE SKIP_RPL.OrderKey = PD.OrderKey
                              AND SKIP_RPL.StorerKey = RPL.StorerKey  
                              AND SKIP_RPL.SKU = PD.SKU
                              AND SKIP_RPL.AddWho = @c_UserName
                              AND SKIP_RPL.Status = 'X')
            -- Not to get the same loc within the same orders
            AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL2 WITH (NOLOCK)
                              WHERE SKIP_RPL2.OrderKey = PD.OrderKey
                              AND SKIP_RPL2.StorerKey = RPL.StorerKey  
                              AND SKIP_RPL2.AddWho <> @c_UserName
                              AND SKIP_RPL2.Status = '1'
                              AND SKIP_RPL2.LOC = pd.LOC )
         ORDER BY SKU.BUSR6
         
         -- If still got same itemclass to continue pick
         IF ISNULL( @c_Busr6, '') <> ''
            SET @n_SkipSearch = 1
   	END

      IF @n_SkipSearch = 0
   	BEGIN
   	   -- Look for the smallest LocAisle
         SELECT TOP 1
            @c_LocAisle = SUBSTRING(L.LocAisle, 1, 2)
         FROM RDT.RDTPickLock RPL WITH (NOLOCK)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         WHERE RPL.StorerKey = @c_StorerKey
            AND RPL.Status < '9'
            AND RPL.AddWho = @c_UserName
            AND PD.Status = '0'
            AND (( ISNULL( @c_PutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @c_PutAwayZone))
            AND (( ISNULL(@c_PickZone, '') = '') OR ( L.PickZone = @c_PickZone))
            AND L.Facility = @c_Facility
            AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL WITH (NOLOCK)
                              WHERE SKIP_RPL.OrderKey = PD.OrderKey
                              AND SKIP_RPL.StorerKey = RPL.StorerKey  
                              AND SKIP_RPL.SKU = PD.SKU
                              AND SKIP_RPL.AddWho = @c_UserName
                              AND SKIP_RPL.Status = 'X')
            -- Not to get the same loc within the same orders
            AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL2 WITH (NOLOCK)
                              WHERE SKIP_RPL2.OrderKey = PD.OrderKey
                              AND SKIP_RPL2.StorerKey = RPL.StorerKey  
                              AND SKIP_RPL2.AddWho <> @c_UserName
                              AND SKIP_RPL2.Status = '1'
                              AND SKIP_RPL2.LOC = pd.LOC )
         ORDER BY 1

         IF @n_Debug = 1
            SELECT @c_LocAisle '@c_LocAisle', @c_StorerKey '@c_StorerKey', @c_UserName '@c_UserName', @c_PutAwayZone '@c_PutAwayZone', @c_PickZone '@c_PickZone', @c_Facility '@c_Facility'
         
         SET @curHighestMat = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT DISTINCT SKU.ItemClass
         FROM RDT.RDTPickLock RPL WITH (NOLOCK)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
         WHERE RPL.StorerKey = @c_StorerKey
            AND RPL.Status < '9'
            AND RPL.AddWho = @c_UserName
            AND PD.Status = '0'
            AND (( ISNULL( @c_PutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @c_PutAwayZone))
            AND (( ISNULL(@c_PickZone, '') = '') OR ( L.PickZone = @c_PickZone))
            AND L.Facility = @c_Facility
            AND SUBSTRING(L.LocAisle, 1, 2) = @c_LocAisle
            AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL WITH (NOLOCK)
                              WHERE SKIP_RPL.OrderKey = PD.OrderKey
                              AND SKIP_RPL.StorerKey = RPL.StorerKey  
                              AND SKIP_RPL.SKU = PD.SKU
                              AND SKIP_RPL.AddWho = @c_UserName
                              AND SKIP_RPL.Status = 'X')
            -- Not to get the same loc within the same orders
            AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL2 WITH (NOLOCK)
                              WHERE SKIP_RPL2.OrderKey = PD.OrderKey
                              AND SKIP_RPL2.StorerKey = RPL.StorerKey  
                              AND SKIP_RPL2.AddWho <> @c_UserName
                              AND SKIP_RPL2.Status = '1'
                              AND SKIP_RPL2.LOC = pd.LOC )
         ORDER BY 1
         OPEN @curHighestMat
         FETCH NEXT FROM @curHighestMat INTO @c_ItemClass
         WHILE @@FETCH_STATUS = 0
         BEGIN
            INSERT INTO @t
            (ItemClass,	Cnt)
            SELECT @c_ItemClass AS ItemClass, COUNT( DISTINCT L.Loc)
            FROM RDT.RDTPickLock RPL WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
            JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
            WHERE RPL.StorerKey = @c_StorerKey
               AND RPL.Status < '9'
               AND RPL.AddWho = @c_UserName
               AND PD.Status = '0'
               AND (( ISNULL( @c_PutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @c_PutAwayZone))
               AND (( ISNULL(@c_PickZone, '') = '') OR ( L.PickZone = @c_PickZone))
               AND L.Facility = @c_Facility
               AND SUBSTRING(L.LocAisle, 1, 2) = @c_LocAisle
               AND SKU.itemclass = @c_ItemClass
               AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL WITH (NOLOCK)
                                 WHERE SKIP_RPL.OrderKey = PD.OrderKey
                                 AND SKIP_RPL.StorerKey = RPL.StorerKey  
                                 AND SKIP_RPL.SKU = PD.SKU
                                 AND SKIP_RPL.AddWho = @c_UserName
                                 AND SKIP_RPL.Status = 'X')
               -- Not to get the same loc within the same orders
               AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL2 WITH (NOLOCK)
                                 WHERE SKIP_RPL2.OrderKey = PD.OrderKey
                                 AND SKIP_RPL2.StorerKey = RPL.StorerKey  
                                 AND SKIP_RPL2.AddWho <> @c_UserName
                                 AND SKIP_RPL2.Status = '1'
                                 AND SKIP_RPL2.LOC = pd.LOC )

            FETCH NEXT FROM @curHighestMat INTO @c_ItemClass	
         END
         
         SELECT TOP 1
            @c_ItemClass = ItemClass
         FROM @t
         ORDER BY Cnt DESC
         
         IF @n_Debug = 1
            SELECT @c_ItemClass '@c_ItemClass'
            
         IF @n_Debug = 1
            SELECT @c_ItemClass '@c_ItemClass', @n_PD_Qty '@n_PD_Qty'

         -- Look for smallest size (SKU.Busr6)
         SELECT TOP 1
            @c_Busr6 = SKU.BUSR6
         FROM RDT.RDTPickLock RPL WITH (NOLOCK)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
         WHERE RPL.StorerKey = @c_StorerKey
            AND RPL.Status < '9'
            AND RPL.AddWho = @c_UserName
            AND PD.Status = '0'
            AND (( ISNULL( @c_PutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @c_PutAwayZone))
            AND (( ISNULL(@c_PickZone, '') = '') OR ( L.PickZone = @c_PickZone))
            AND L.Facility = @c_Facility
            AND SKU.itemclass = @c_ItemClass
            AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL WITH (NOLOCK)
                              WHERE SKIP_RPL.OrderKey = PD.OrderKey
                              AND SKIP_RPL.StorerKey = RPL.StorerKey  
                              AND SKIP_RPL.SKU = PD.SKU
                              AND SKIP_RPL.AddWho = @c_UserName
                              AND SKIP_RPL.Status = 'X')
            -- Not to get the same loc within the same orders
            AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL2 WITH (NOLOCK)
                              WHERE SKIP_RPL2.OrderKey = PD.OrderKey
                              AND SKIP_RPL2.StorerKey = RPL.StorerKey  
                              AND SKIP_RPL2.AddWho <> @c_UserName
                              AND SKIP_RPL2.Status = '1'
                              AND SKIP_RPL2.LOC = pd.LOC )
         ORDER BY SKU.BUSR6

         IF @n_Debug = 1
            SELECT @c_Busr6 '@c_Busr6'
      END
   
      SELECT TOP 1
         @c_oFieled01 = PD.Loc,
         @c_oFieled02 = PD.OrderKey,
         @c_oFieled03 = PD.SKU,
         @c_oFieled09 = PD.LOT,
         @c_oFieled10 = PD.PickSlipNo
      FROM RDT.RDTPickLock RPL WITH (NOLOCK)
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
      JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
      WHERE RPL.StorerKey = @c_StorerKey
         AND RPL.Status < '9'
         AND RPL.AddWho = @c_UserName
         AND PD.Status = '0'
         AND (( ISNULL( @c_PutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @c_PutAwayZone))
         AND (( ISNULL(@c_PickZone, '') = '') OR ( L.PickZone = @c_PickZone))
         AND L.Facility = @c_Facility
         AND SKU.itemclass = @c_ItemClass
         AND SKU.BUSR6 = @c_Busr6
         AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL WITH (NOLOCK)
                           WHERE SKIP_RPL.OrderKey = PD.OrderKey
                           AND SKIP_RPL.StorerKey = RPL.StorerKey  
                           AND SKIP_RPL.SKU = PD.SKU
                           AND SKIP_RPL.AddWho = @c_UserName
                           AND SKIP_RPL.Status = 'X')
         -- Not to get the same loc within the same orders
         AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL2 WITH (NOLOCK)
                           WHERE SKIP_RPL2.OrderKey = PD.OrderKey
                           AND SKIP_RPL2.StorerKey = RPL.StorerKey  
                           AND SKIP_RPL2.AddWho <> @c_UserName
                           AND SKIP_RPL2.Status = '1'
                           AND SKIP_RPL2.LOC = pd.LOC )
      GROUP BY L.LogicalLocation, PD.Loc, PD.OrderKey, PD.SKU, PD.LOT, PD.PickSlipNo
      ORDER BY L.LogicalLocation, PD.LOC, PD.SKU, PD.OrderKey    
   END
   ELSE
      SELECT TOP 1
         @c_oFieled01 = PD.Loc,
         @c_oFieled02 = PD.OrderKey,
         @c_oFieled03 = PD.SKU,
         @c_oFieled09 = PD.LOT,
         @c_oFieled10 = PD.PickSlipNo
      FROM RDT.RDTPickLock RPL WITH (NOLOCK)
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
      JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
      WHERE RPL.StorerKey = @c_StorerKey
         AND RPL.Status < '9'
         AND RPL.AddWho = @c_UserName
         AND PD.Status = '0'
         AND (( ISNULL( @c_PutAwayZone, '') = 'ALL') OR ( L.PutAwayZone = @c_PutAwayZone))
         AND (( ISNULL(@c_PickZone, '') = '') OR ( L.PickZone = @c_PickZone))
         AND L.Facility = @c_Facility
         AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL WITH (NOLOCK)
                         WHERE SKIP_RPL.OrderKey = PD.OrderKey
                         AND SKIP_RPL.StorerKey = RPL.StorerKey  
                         AND SKIP_RPL.SKU = PD.SKU
                         AND SKIP_RPL.AddWho = @c_UserName
                         AND SKIP_RPL.Status = 'X')
         -- Not to get the same loc within the same orders
         AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock SKIP_RPL2 WITH (NOLOCK)
                         WHERE SKIP_RPL2.OrderKey = PD.OrderKey
                         AND SKIP_RPL2.StorerKey = RPL.StorerKey  -- TLTING02
                         AND SKIP_RPL2.AddWho <> @c_UserName
                         AND SKIP_RPL2.Status = '1'
                         AND SKIP_RPL2.LOC = pd.LOC )  -- james02
      ORDER BY L.LogicalLocation, PD.LOC, PD.SKU, RPL.OrderKey    
      
   IF @@ROWCOUNT = 0  
   BEGIN  
      SET @c_oFieled02 = ''  
      GOTO Quit  
   END  

   SELECT @c_oFieled04 = SKU.DESCR,
      @c_oFieled05 = SKU.Style,
      @c_oFieled06 = SKU.Color,
      @c_oFieled07 = SKU.Size,
      @c_oFieled08 = SKU.BUSR7
   FROM dbo.SKU SKU WITH (NOLOCK)
   WHERE SKU.Storerkey = @c_StorerKey
   AND   SKU.SKU = @c_oFieled03

   SELECT
      @c_oFieled11 = ExternOrderKey,
      @c_oFieled12 = ConsigneeKey
   FROM dbo.Orders WITH (NOLOCK)
   WHERE StorerKey = @c_StorerKey
   AND   OrderKey = @c_oFieled02

   SELECT
      @c_oFieled13 = Lottable02,
      @c_oFieled14 = Lottable04
   FROM dbo.LOTATTRIBUTE WITH (NOLOCK)
   WHERE Lot = @c_oFieled09
   
   Quit:
END 

GO
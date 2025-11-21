SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: rdtfnc_Move                              */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Iventory move by                                            */  
/*          1) Pallet ID                                                */  
/*          2) Location                                                 */  
/*          3) SKU                                                      */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/*              Manny         Created                                   */  
/*              Shong         Various fixes                             */  
/* 25-08-2005   dhung       - SOS# 39756. Move should not be allowed on */  
/*                            item with qty-qtypicked <= 0              */  
/*                          - SOS# 39758. Provide two lines for full SKU*/  
/*                            description display                       */  
/*                          - SOS# 39749. Move by location, move by SKU */  
/*                            always hit 'LOC has multiple ID' error if */  
/*                            the location is double deep               */  
/*                          - SOS# 39746. QTY show as UOM QTY           */  
/*                          - SOS# 40003. Move by SKU, if the LOC has   */  
/*                            more than 1 ID (for e.g. double deep LOC  */  
/*                            that has 2 pallets), need to key-in the ID*/  
/*                            specify which ID to move                  */  
/*                          - SOS# 40166. Move by Pallet, display SKU   */  
/*                            description if pallet contain only 1 SKU. */  
/*                            Display SKU count if pallet contain more  */  
/*                            than 1 SKU                                */  
/*                          - SOS# 54342. Move by SKU should not check  */  
/*                            QTYAllocated on LOC level                 */  
/* 25-05-2010   Leong       - SOS# 174316 - Not allow to move when Loc  */  
/*                                          being allocated / picked.   */  
/*                                          (According to New Standard) */  
/* 2010-09-15 1.5  Shong    QtyAvailable Should exclude QtyReplen       */  
/* 2016-09-30 1.6  Ung      Performance tuning                          */
/* 2015-05-10 1.7  James    Add optional param in itrnaddmove (james01) */
/* 2018-11-02 1.8  Gan      Performance tuning                          */
/************************************************************************/  
  
CREATE  PROC [RDT].[rdtfnc_Move] (  
   @nMobile    int,  
   @nErrNo     int  OUTPUT,  
   @cErrMsg    NVARCHAR(1024) OUTPUT  
)  
AS
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
  
-- Define a variable  
DECLARE @nFunc     int,  
      @nScn        int,  
      @nStep       int,  
      @cLangCode   NVARCHAR(3),  
      @cPassword   NVARCHAR(15),  
      @cStorer     NVARCHAR(15),  
      @cFacility   NVARCHAR(5),  
      @cSKU        NVARCHAR(20),  
      @nInputKey   int,  
      @nMenu       int,  
      @cI_Field01  NVARCHAR(60),  
      @cI_Field02  NVARCHAR(60),  
      @cI_Field03  NVARCHAR(60),  
      @cI_Field04  NVARCHAR(60),  
      @cI_Field05  NVARCHAR(60),  
      @cI_Field06  NVARCHAR(60),  
      @cI_Field07  NVARCHAR(60),  
      @cI_Field08  NVARCHAR(60),  
      @cI_Field09  NVARCHAR(60),  
      @cI_Field10  NVARCHAR(60),  
      @cI_Field11  NVARCHAR(60),  
      @cI_Field12  NVARCHAR(60),  
      @cI_Field13  NVARCHAR(60),  
      @cI_Field14  NVARCHAR(60),  
      @cI_Field15  NVARCHAR(60),  
      @cO_Field01  NVARCHAR(60),  
      @cO_Field02  NVARCHAR(60),  
      @cO_Field03  NVARCHAR(60),  
      @cO_Field04  NVARCHAR(60),  
      @cO_Field05  NVARCHAR(60),  
      @cO_Field06  NVARCHAR(60),  
      @cO_Field07  NVARCHAR(60),  
      @cO_Field08  NVARCHAR(60),  
      @cO_Field09  NVARCHAR(60),  
      @cO_Field10  NVARCHAR(60),  
      @cO_Field11  NVARCHAR(60),  
      @cO_Field12  NVARCHAR(60),  
      @cO_Field13  NVARCHAR(60),  
      @cO_Field14  NVARCHAR(60),  
      @cO_Field15  NVARCHAR(60),  
      @cLoc        NVARCHAR(20),  
      @nRecordcount int,  
      @nSumQty      int,  
      @nSumQtyAlloc int,  
      @nQty         int,  
      @cLot        NVARCHAR(10),  
      @cPackKey    NVARCHAR(10),  
      @cUOM        NVARCHAR(10),  
      @cUserName   NVARCHAR( 15),  
      @nQTYInUOM   int,  
      @nLLIQty     int,  
      @nQTYRemain  int,  
      @nQTYToMove  int,  
      @b_success   int,  
      @n_err       int,  
      @c_errmsg    NVARCHAR(1024),  
      @nQtyAvailable  int,  
      @nQtyAvailInUOM int,       -- SOS 39746  
      @cPackUOM3      NVARCHAR( 10), -- SOS 39746  
      @cID            NVARCHAR( 18)  
  
-- Getting Mobile information  
SELECT @nFunc      = Func,  
      @nScn       = Scn,  
      @nStep      = Step,  
      @cI_Field01 = I_Field01,  
      @cI_Field02 = I_Field02,  
      @cI_Field03 = I_Field03,  
      @cI_Field04 = I_Field04,  
      @cI_Field05 = I_Field05,  
      @cI_Field06 = I_Field06,  
      @cI_Field07 = I_Field07,  
      @cI_Field08 = I_Field08,  
      @cI_Field09 = I_Field09,  
      @cI_Field10 = I_Field10,  
      @cI_Field11 = I_Field11,  
      @cI_Field12 = I_Field12,  
      @cI_Field13 = I_Field13,  
      @cI_Field14 = I_Field14,  
      @cI_Field15 = I_Field15,  
      @nInputKey  = InputKey,  
      @cLangCode  = Lang_code,  
      @cStorer    = StorerKey,  
      @cFacility  = Facility,  
      @cUserName  = UserName,  
      @cLoc       = V_Loc,  
      @cUOM       = V_UOM,  
      @nMenu      = Menu,  
      @cSKU       = V_SKU,  
      @cO_Field01 = O_Field01,  
      @cO_Field02 = O_Field02,  
      @cO_Field03 = O_Field03,  
      @cO_Field04 = O_Field04,  
      @cO_Field05 = O_Field05,  
      @cO_Field06 = O_Field06,  
      @cO_Field07 = O_Field07,  
      @cO_Field08 = O_Field08,  
      @cO_Field09 = O_Field09,  
      @cO_Field10 = O_Field10,  
      @cO_Field11 = O_Field11,  
      @cO_Field12 = O_Field12,  
      @cO_Field13 = O_Field13,  
      @cO_Field14 = O_Field14,  
      @cO_Field15 = O_Field15  
      FROM   RDTMOBREC (NOLOCK)  
      WHERE Mobile = @nMobile  
  
-- Get default UOM  
SELECT @cUOM = DefaultUOM  
FROM RDTUser (NOLOCK)  
WHERE UserName = @cUserName  
  
/**************************************************************************************************  
Function  
   511 = By Pallet  
   512 = By Location  
   513 = By SKU  
**************************************************************************************************/  
IF @nStep = 0  
BEGIN  
     IF   @nFunc =  511  -- Move by Pallet ID  
          SET @cO_Field15 = rdt.rdtgetmessage( 14, @cLangCode,'DSP') -- Pallet ID:  
     ELSE  
          SET @cO_Field15 = rdt.rdtgetmessage( 15, @cLangCode,'DSP') -- Loc  
  
     SELECT @cO_Field01 = '',@cO_Field02 = '',@cO_Field03 = '',@cO_Field04 = '',@cO_Field05 = ''  
     SELECT @cO_Field06 = '',@cO_Field07 = '',@cO_Field08 = '',@cO_Field09 = '',@cO_Field10 = ''  
     SELECT @cO_Field11 = '',@cO_Field12 = '',@cO_Field13 = '',@cO_Field14 = ''  
  
     SET @nScn = 804  
     SET @nStep = 1  
END  
ELSE IF @nStep = 1  
BEGIN  
   IF @nInputKey = 1      -- Yes or Send  
   BEGIN  
      IF RTRIM(@cI_Field01) != ''  
      BEGIN  
         IF @nFunc =  511  -- Move by Pallet ID  
         BEGIN  
            -- ID lookup  
            -- SOS# 39746 - start  
            SELECT  
               @nRecordcount = COUNT( DISTINCT( LOC.LOC)),  
               @cO_Field04 = COUNT( DISTINCT( LLI.SKU)),  
               @nSumQty = SUM( CASE @cUOM  
                              WHEN '1' THEN FLOOR( LLI.QTY / PACK.Pallet)  
                              WHEN '2' THEN FLOOR( LLI.QTY / PACK.CaseCnt)  
                              WHEN '3' THEN FLOOR( LLI.QTY / PACK.InnerPack)  
                              WHEN '4' THEN FLOOR( LLI.QTY / PACK.OtherUnit1)  
                              WHEN '5' THEN FLOOR( LLI.QTY / PACK.OtherUnit2)  
                              ELSE LLI.QTY END),  
               @nSumQtyAlloc = SUM( LLI.QtyAllocated + LLI.QtyPicked + (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) -- SOS# 39756  
            FROM dbo.LOTxLOCxID LLI (NOLOCK)  
               INNER JOIN dbo.LOC LOC (NOLOCK) ON LLI.LOC = LOC.LOC  
               INNER JOIN dbo.SKU SKU (NOLOCK) ON LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU  
               INNER JOIN dbo.Pack Pack (NOLOCK) ON SKU.PackKey = Pack.PackKey  
            WHERE LLI.ID  = @cI_Field01  
              AND LLI.StorerKey = @cStorer  
              AND LOC.Facility = @cFacility  
              AND LLI.Qty > 0  
            -- SOS# 39746 - end  
  
            IF @nRecordcount = 0  
            BEGIN  
                SET @cErrMsg = rdt.rdtgetmessage( 12, @cLangCode,'DSP') -- No records (PID)  
            END  
            ELSE IF @nRecordcount > 1  
            BEGIN  
                SET @cErrMsg = rdt.rdtgetmessage( 16, @cLangCode,'DSP') -- PID in multiple loc  
            END  
            ELSE IF @nSumQtyAlloc > 0  
            BEGIN  
                SET @cErrMsg = rdt.rdtgetmessage( 17, @cLangCode,'DSP') -- Alloc / Pick Qty > 0  
            END  
            ELSE  
            BEGIN  
               DECLARE C_ID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT  A.Sku + space(2) + cast(SUM(CASE @cUOM WHEN '1' THEN FLOOR(a.QTY / P.Pallet)  
                                                          WHEN '2' THEN FLOOR(a.QTY / P.CaseCnt)  
                                                          WHEN '3' THEN FLOOR(a.QTY / P.InnerPack)  
                                                          WHEN '4' THEN FLOOR(a.QTY / P.OtherUnit1)  
                                                          WHEN '5' THEN FLOOR(a.QTY / P.OtherUnit2)  
                                                          ELSE  a.QTY  
                                               END) AS NVARCHAR(10)), A.loc  
               FROM dbo.LOTxLOCxID a (nolock)  
               JOIN dbo.SKU B (nolock) ON A.StorerKey = B.Storerkey AND A.SKU = B.SKU  
               JOIN dbo.Loc C (nolock) ON A.loc = C.loc  
               JOIN dbo.PACK P (NOLOCK) ON B.PackKey = P.PackKey  
               WHERE A.ID = RTRIM(@cI_Field01) AND  
                     A.StorerKey = @cStorer AND  
                     A.QtyAllocated = 0 and  
                     A.Qty > 0 AND  
                     C.Facility = @cFacility  
               GROUP BY A.Sku, A.loc  
               ORDER BY A.SKU, A.LOC  
  
               OPEN C_ID  
  
               FETCH NEXT FROM C_ID INTO @cO_Field01, @cLoc  
  
               IF @@FETCH_STATUS <> -1  
                  FETCH NEXT FROM C_ID INTO @cO_Field02, @cLoc  
               IF @@FETCH_STATUS <> -1  
                  FETCH NEXT FROM C_ID INTO @cO_Field03, @cLoc  
               CLOSE C_ID  
               DEALLOCATE C_ID  
  
               IF rdt.rdtgetcfg (@nFunc,'show_pickf', @cStorer) = 1 AND cast(@cO_Field04 as INT)= 1  
               BEGIN  
                  SET ROWCOUNT 1  
  
                  SELECT  @cO_Field12 = 'Pickface: '+rtrim(a.loc) + ' Qty:' + CAST(a.QTY AS NVARCHAR(8))  
                          + ' Alloc: '+CAST(a.QtyAllocated AS NVARCHAR(8))  
                  FROM dbo.LOTxLOCxID a (nolock), dbo.Loc C (nolock)  
                  WHERE A.ID = RTRIM(@cI_Field01) AND A.StorerKey = @cStorer AND  
                  A.loc = C.loc  AND C.LOCATIONTYPE = 'PICK'  
                  ORDER BY A.QTY  
  
                  SET ROWCOUNT 0  
               END  
               ELSE  
               BEGIN  
                  SET @cO_Field12 = ''  
               END  
  
               -- SOS40166 - show sku descr if pallet only has 1 SKU - start  
               IF CAST( @cO_Field04 AS INT) = 1  
               BEGIN  
                  SET ROWCOUNT 1  
                  SELECT  
                     @cO_Field09 = SKU.SKU,  
                     @cO_Field03 = SUBSTRING( SKU.Descr,  1, 20),  
                     @cO_Field07 = SUBSTRING( SKU.Descr, 21, 20)  
                  FROM dbo.LOTxLOCxID LLI (NOLOCK)  
                     INNER JOIN dbo.LOC LOC (NOLOCK) ON LLI.LOC = LOC.LOC  
                     INNER JOIN dbo.SKU SKU (NOLOCK) ON LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU  
                  WHERE LLI.ID  = @cI_Field01  
                    AND LLI.StorerKey = @cStorer  
                    AND LOC.Facility = @cFacility  
                    AND LLI.Qty > 0  
                  SET ROWCOUNT 0  
               END  
               ELSE  
               BEGIN  
                  SET @cO_Field03 = ''  
                  SET @cO_Field07 = ''  
                  SET @cO_Field09 = ''  
               END  
               -- SOS40166 - show sku descr if pallet only has 1 SKU - end  
  
               SET @cO_Field14  = RTRIM(@cI_Field01)  
               SET @cO_Field13  = 'ID: ' + @cO_Field14  
               SET @cO_Field11  = 'Loc: ' + @cLoc  
               SET @cO_Field04  = 'SKUs ' + @cO_Field04 + ' Qty ' + cast(@nSumQty AS NVARCHAR(10))  
               SELECT @cO_Field02 = 'To LOC:'  
  
               SET @nStep = 2  
               SET @nScn = 805  
  
            END  
         END-- IF @nFunc =  511  
         ELSE IF @nFunc =  512 or  @nFunc =  513 -- Move by Location  
         BEGIN  
            -- Loc/SKU lookup  
            -- SOS# 39746 - start  
            SELECT  
               @nRecordcount = COUNT( DISTINCT( LLI.ID)),  
               @cO_Field04 = COUNT( DISTINCT( LLI.SKU)),  
               @nSumQty = SUM( CASE @cUOM  
                              WHEN '1' THEN FLOOR( LLI.QTY / PACK.Pallet)  
                              WHEN '2' THEN FLOOR( LLI.QTY / PACK.CaseCnt)  
                              WHEN '3' THEN FLOOR( LLI.QTY / PACK.InnerPack)  
                              WHEN '4' THEN FLOOR( LLI.QTY / PACK.OtherUnit1)  
                              WHEN '5' THEN FLOOR( LLI.QTY / PACK.OtherUnit2)  
                              ELSE LLI.QTY END),  
               @nSumQtyAlloc = SUM( LLI.QtyAllocated + LLI.QtyPicked + (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END))  
            FROM dbo.LOTxLOCxID LLI (NOLOCK)  
               INNER JOIN dbo.LOC LOC (NOLOCK) ON LLI.LOC = LOC.LOC  
               INNER JOIN dbo.SKU SKU (NOLOCK) ON LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU  
               INNER JOIN dbo.Pack Pack (NOLOCK) ON SKU.PackKey = Pack.PackKey  
            WHERE  LLI.LOC  = @cI_Field01  
               AND LLI.StorerKey = @cStorer  
               AND LLI.Qty > 0  
               AND LOC.Facility = @cFacility  
            -- SOS# 39746 - end  
  
            IF @nRecordcount = 0  
            BEGIN  
                SET @cErrMsg = RTRIM(rdt.rdtgetmessage( 11, @cLangCode,'DSP')) -- No records (LOC)  
            END  
            /* -- SOS39749  
            ELSE IF @nRecordcount > 1  
            BEGIN  
                SET @cErrMsg = RTRIM(rdt.rdtgetmessage( 35, @cLangCode,'DSP')) -- LOC has multiple ID  
            END  
            */  
            -- ELSE IF (@nFunc =  512) AND (@nSumQtyAlloc > 0) -- SOS# 174316  
            ELSE IF @nSumQtyAlloc > 0                          -- SOS# 174316  
            BEGIN  
                SET @cErrMsg = rdt.rdtgetmessage( 17, @cLangCode,'DSP') -- Alloc / Pick Qty > 0  
            END  
            ELSE  
            BEGIN  
               IF rdt.rdtgetcfg (@nFunc,'show_pickf', @cStorer) = 1 AND cast(@cO_Field04 as INT)= 1  
               BEGIN  
                  SELECT  @cO_Field12 = 'Pick: '+ RTRIM(a.loc) + ' Qty:' +  
                          CAST(SUM(CASE @cUOM WHEN '1' THEN FLOOR(a.QTY / P.Pallet)  
                                              WHEN '2' THEN FLOOR(a.QTY / P.CaseCnt)  
                                              WHEN '3' THEN FLOOR(a.QTY / P.InnerPack)  
                                              WHEN '4' THEN FLOOR(a.QTY / P.OtherUnit1)  
                                              WHEN '5' THEN FLOOR(a.QTY / P.OtherUnit2)  
                                              ELSE  a.QTY  
                                   END) AS NVARCHAR(8))  
                          + ' Alloc: '+ CAST(SUM(CASE @cUOM WHEN '1' THEN FLOOR(a.QtyAllocated / P.Pallet)  
                                              WHEN '2' THEN FLOOR(a.QtyAllocated / P.CaseCnt)  
                                              WHEN '3' THEN FLOOR(a.QtyAllocated / P.InnerPack)  
                                              WHEN '4' THEN FLOOR(a.QtyAllocated / P.OtherUnit1)  
                                              WHEN '5' THEN FLOOR(a.QtyAllocated / P.OtherUnit2)  
                                              ELSE  a.QtyAllocated  
                                   END) AS NVARCHAR(8))  
                  FROM dbo.SKUxLOC A (nolock)  
                  JOIN dbo.SKU  SKU  (nolock) ON A.StorerKey = SKU.StorerKey AND A.SKU = SKU.SKU  
                  JOIN dbo.PACK P (NOLOCK) ON SKU.PackKey = P.PackKey  
                  JOIN dbo.LOC LOC (NOLOCK) ON LOC.LOC = A.LOC  
                  WHERE A.SKU = @cSKU AND  
                        A.StorerKey = @cStorer AND  
                        A.LOCATIONTYPE IN ('PICK', 'CASE') AND  
                        LOC.Facility = @cFacility  
                  GROUP BY A.LOC  
               END-- if show_pick turn on  
  
               SELECT @cO_Field02 = CASE @nFunc WHEN 512 THEN 'To Loc:'  
                                                WHEN 513 THEN 'SKU:'  
                                    END  
  
               SET @cLoc = RTRIM(@cI_Field01)  
               SET @cO_Field13  = 'Loc: ' + @cLoc  
               SET @cO_Field04  = 'SKUs ' + @cO_Field04 + ' Qty ' + cast(@nSumQty AS NVARCHAR(10))  
  
               SET @nStep = 2  
               SET @nScn = 805  
            END-- IF @nRecordcount = 1  
         END-- IF @nFunc =  512 or  @nFunc =  513  
      END-- if input is not blank  
      ELSE  
      BEGIN  
        SET @cErrMsg = RTRIM(rdt.rdtgetmessage(13, @cLangCode,'DSP')) -- Enter Value!  
      END  
   END-- IF @nInputKey = 1  
   ELSE IF @nInputKey = 0 -- Esc or No  
   BEGIN  
       -- Cancel, Do What?  
       SET @cI_Field01 = ''  
       SET @cO_Field01 = ''  
       SET @cO_Field15 = ''  
       SET @nFunc = @nMenu  
       SET @nScn  = @nMenu  
       SET @nStep = 0  
   END  
END  
ELSE IF @nStep = 2  
BEGIN  
   IF @nInputKey = 1      -- Yes or Send  
   BEGIN  
      IF @nFunc =  511 AND RTRIM(@cI_Field05) != ''  
      BEGIN  
         -- Find and Check ToLoc  
         DECLARE @nQtyAllocated int  
  
         SELECT @nRecordcount = count(*)  
         FROM   dbo.LOC A (nolock)  
         WHERE  A.LOC  = RTRIM(@cI_Field05)  
         AND    A.Facility = @cFacility  
  
         IF @nRecordcount > 0 --AND MaxPallet = 0  
         BEGIN  
             DECLARE C_ID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
             --SELECT  A.Sku, A.lot, A.loc, A.qty, b.PackKey, C.packuom3  
             SELECT  A.Sku, A.lot, A.loc,   
                     A.Qty - A.QtyAllocated - A.QtyPicked - (CASE WHEN A.QtyReplen < 0 THEN 0 ELSE A.QtyReplen END),   
                     b.PackKey, C.packuom3-- SOS# 174316  
             FROM dbo.LOTxLOCxID a (nolock), dbo.SKU B (nolock),  
                  dbo.PACK   C (nolock), dbo.LOC D (NOLOCK)  
             WHERE A.ID = @cO_Field14 AND A.StorerKey = @cStorer AND  
                   A.StorerKey = B.Storerkey AND A.SKU = B.SKU AND  
                   B.PackKey = C.PackKey AND  
                   --A.QtyAllocated = 0 and A.Qty > 0 AND         -- SOS# 174316  
                   (A.Qty - A.QtyAllocated - A.QtyPicked - (CASE WHEN A.QtyReplen < 0 THEN 0 ELSE A.QtyReplen END)) > 0 AND -- SOS# 174316  
                   A.LOC = D.LOC AND  
                   D.Facility = @cFacility  
             ORDER BY A.LOC, (A.Qty - A.QtyAllocated - A.QtyPicked - (CASE WHEN A.QtyReplen < 0 THEN 0 ELSE A.QtyReplen END)) --A.Qty -- SOS# 174316  
  
             OPEN C_ID  
  
             FETCH NEXT FROM C_ID INTO @cSKU, @cLot,@cLoc,@nQty,@cPackKey, @cPackUOM3 -- SOS 39746  
             SET @cErrMsg = ''  
  
             WHILE  @@FETCH_STATUS <> -1  
             BEGIN  
                IF @@FETCH_STATUS <> -1  
                BEGIN -- Move each SKU  
                   EXEC dbo.nspItrnAddMove NULL,  
                     @cStorer,  
                     @cSKU,  
                     @cLot,  
                     @cLoc,  
                     @cO_Field14,  
                     @cI_Field05,  
                     @cO_Field14,  
                     '','','','','','',  
                     '','','','','','', '','','','','','','',NULL,NULL,NULL,
                     0,0, @nQty,  0,0,0,0,0,0,  
                     @cO_Field14,  
                     'rdt_fncMove',  
                     @cPackKey,  
                     @cPackUOM3,  
                     1,  
                     '',  
                     '',  
                     @b_Success OUTPUT , @n_err     OUTPUT , @c_errmsg  OUTPUT  
  
                   IF  @b_success != 1  
                      SET @cErrMsg = cast (@b_success AS NVARCHAR(3))  
  
                   FETCH NEXT FROM C_ID INTO @cSKU, @cLot,@cLoc,@nQty,@cPackKey, @cPackUOM3 -- SOS 39746  
                END-- IF @@FETCH_STATUS <> -1  
             END-- WHILE -- @@FETCH_STATUS <> -1  
  
            CLOSE C_ID  
            DEALLOCATE C_ID  
  
            SET @nScn = 804  
            SET @nStep = 1  
            SET @cErrMsg = @cErrMsg + ' ' + rdt.rdtgetmessage( 18, @cLangCode,'DSP') + RTRIM(@cI_Field05) -- Mvd to:  
            SELECT @cO_Field01 = '',@cO_Field02 = '',@cO_Field03 = '',@cO_Field04 = '',@cO_Field05 = ''  
            SELECT @cO_Field06 = '',@cO_Field07 = '',@cO_Field08 = '',@cO_Field09 = '',@cO_Field10 = ''  
            SELECT @cO_Field11 = '',@cO_Field12 = '',@cO_Field13 = '',@cO_Field14 = ''  
         END-- @nRecordcount > 0  
         ELSE  
         BEGIN  
            SET @cErrMsg =  rdt.rdtgetmessage( 19, @cLangCode,'DSP') + ' ' + RTRIM(@cI_Field05) -- No records (LOC)  
         END  
      END-- @nFunc =  511  
      ELSE IF @nFunc =  512 AND RTRIM(@cI_Field05) != ''  
      BEGIN  
         -- Find and Check ToLoc  
  
         SELECT @nRecordcount = count(*) --, LocationType, LocationFlag , Status, MaxPallet  
         FROM dbo.LOC A (nolock)  
         WHERE  A.LOC  = RTRIM(@cI_Field05)  
         AND    A.Facility = RTRIM(@cFacility)  
  
         IF @nRecordcount > 0  
         BEGIN  
            DECLARE C_LOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT  A.Sku , A.lot , A.id, A.Qty - A.QtyAllocated - A.QtyPicked - (CASE WHEN A.QtyReplen < 0 THEN 0 ELSE A.QtyReplen END),  
                    b.PackKey,  
                    C.packuom3  
            FROM dbo.LOTxLOCxID a (nolock),  
                 dbo.SKU B (nolock),  
                 dbo.PACK   C (nolock),  
                 dbo.LOC D (NOLOCK)  
            WHERE A.LOC = @cLoc AND A.StorerKey = @cStorer AND  
                A.StorerKey = B.Storerkey AND A.SKU = B.SKU AND  
                B.PackKey = C.PackKey AND  
                -- A.QtyAllocated = 0 and A.Qty > 0 AND        -- SOS# 174316  
                (A.Qty - A.QtyAllocated - A.QtyPicked - (CASE WHEN A.QtyReplen < 0 THEN 0 ELSE A.QtyReplen END)) > 0 AND -- SOS# 174316  
                A.LOC = D.LOC AND  
                D.Facility = @cFacility  
            ORDER BY A.LOC, (A.Qty - A.QtyAllocated - A.QtyPicked - (CASE WHEN A.QtyReplen < 0 THEN 0 ELSE A.QtyReplen END)) --A.Qty -- SOS# 174316  
  
            OPEN C_LOC  
  
            FETCH NEXT FROM C_LOC INTO @cSKU,@cLot, @cID, @nQty,@cPackKey, @cPackUOM3 -- SOS 39746  
            SET @cErrMsg = ''  
  
            WHILE  @@FETCH_STATUS <> -1  
            BEGIN  
               IF @@FETCH_STATUS <> -1  
               BEGIN -- Move each SKU  
                  EXEC dbo.nspItrnAddMove NULL,  
                     @cStorer,  
                     @cSKU,  
                     @cLot,  
                     @cLoc,  
                     @cID,  
                     @cI_Field05,  
                     @cID,  
                     '','','','','','', '','','','','','','',NULL,NULL,NULL,
                     0,0, @nQty,  0,0,0,0,0,0,  
                     '',  
                     'rdt_fncMove',  
                     @cPackKey,  
                     @cPackUOM3,  
                     1,  
                     '',  
                     '',  
                     @b_Success OUTPUT , @n_err     OUTPUT , @c_errmsg  OUTPUT  
  
                     IF  @b_success != 1  
                        SET @cErrMsg = cast (@b_success AS NVARCHAR(3))  
  
                     FETCH NEXT FROM C_LOC INTO @cSKU, @cLot, @cID, @nQty, @cPackKey, @cPackUOM3 -- SOS 39746  
               END  
            END-- @@FETCH_STATUS <> -1  
  
            CLOSE C_LOC  
            DEALLOCATE C_LOC  
  
            SET @nScn = 804  
            SET @nStep = 1  
            SET @cErrMsg = @cErrMsg + ' ' + rdt.rdtgetmessage( 18, @cLangCode,'DSP') + ' ' + RTRIM(@cI_Field05) -- Mvd to:  
            SELECT @cO_Field01 = '',@cO_Field02 = '',@cO_Field03 = '',@cO_Field04 = '',@cO_Field05 = ''  
            SELECT @cO_Field06 = '',@cO_Field07 = '',@cO_Field08 = '',@cO_Field09 = '',@cO_Field10 = ''  
            SELECT @cO_Field11 = '',@cO_Field12 = '',@cO_Field13 = '',@cO_Field14 = ''  
  
         END-- IF @nRecordcount > 0  
         ELSE  
         BEGIN  
            SET @cErrMsg =  rdt.rdtgetmessage( 19, @cLangCode,'DSP') + ' ' + RTRIM(@cI_Field05) -- No records (LOC)  
         END  
      END-- IF @nFunc =  512 AND RTRIM(@cI_Field05) != ''  
      ELSE IF @nFunc =  513 AND RTRIM(@cI_Field05) != ''  
      BEGIN  
         -- Find and Check ToLoc  
         -- @cO_Field01 = From Loc  
         -- @cO_Field02 = SKU Code  
         -- @cO_Field03 = SKU Description  
         -- @cO_Field04 = UOM  
         -- @cO_Field05 = Qty  
  
       DECLARE @cSKUDescr      NVARCHAR(60)  
  
         SELECT @b_success = 1  
         EXEC dbo.nspg_GETSKU  
                        @cStorer  
         ,              @cI_Field05 OUTPUT  
         ,              @b_success  OUTPUT  
         ,              @n_err      OUTPUT  
         ,              @c_errmsg   OUTPUT  
  
       IF @b_success = 0  
       BEGIN  
            -- Invalid Sku  
            SET @cErrMsg = rdt.rdtgetmessage( 10, @cLangCode,'DSP') -- No records (SKU)  
         END  
         ELSE  
         BEGIN  
            -- SOS39746 - start  
            SELECT @cSKUDescr = DESCR  
            FROM dbo.SKU (NOLOCK)  
            WHERE StorerKey = @cStorer  
              AND SKU = @cI_Field05  
  
            SELECT  
               @nQtyAvailable = SUM( LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)),  
               @nQtyAvailInUOM = SUM(  
                  CASE @cUOM  
                     WHEN '1' THEN FLOOR( (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked   
                                       - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) / Pack.Pallet)  
                     WHEN '2' THEN FLOOR( (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked   
                                       - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) / Pack.CaseCnt)  
                     WHEN '3' THEN FLOOR( (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked   
                                       - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) / Pack.InnerPack)  
                     WHEN '4' THEN FLOOR( (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked   
                                       - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) / Pack.OtherUnit1)  
                     WHEN '5' THEN FLOOR( (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked   
                                       - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) / Pack.OtherUnit2)  
                     ELSE (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END))  
                  END)  
            FROM dbo.LOTxLOCxID LLI (NOLOCK)  
               INNER JOIN dbo.SKU SKU (NOLOCK) ON LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU  
               INNER JOIN dbo.Pack Pack (NOLOCK) ON SKU.PackKey = Pack.PackKey  
            WHERE LLI.SKU = @cI_Field05  
               AND LLI.StorerKey = @cStorer  
               AND LLI.LOC = @cLoc   
               AND (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0   
  
            IF @nQtyAvailable IS NOT NULL  
            -- SOS39746 - end  
            BEGIN  
               IF @nQtyAvailable > 0  
               BEGIN  
                  SET @cSKU = @cI_Field05  
                  SET @nScn = 811  
                  SET @nStep = 3  
                  -- SOS# 39746  
                  SELECT @cO_Field04 =  
                     CASE @cUOM  
                        WHEN '1' THEN 'Pallet'  
                        WHEN '2' THEN 'Carton'  
                        WHEN '3' THEN 'Inner Pack'  
                        WHEN '4' THEN 'Other Unit 1'  
                        WHEN '5' THEN 'Other Unit 2'  
                        WHEN '6' THEN 'Each'  
                        ELSE 'Each'  
                     END  
                  FROM RDTMobRec (NOLOCK)  
                     INNER JOIN RDTUser (NOLOCK) ON (RDTMobRec.UserName = RDTUser.UserName)  
                  WHERE RDTMobRec.Mobile = @nMobile  
  
                  SELECT  @cO_Field02 = @cSKU,  
                          @cO_Field03 = SUBSTRING( @cSKUDescr,  1, 20), -- SOS39758  
                          @cO_Field07 = SUBSTRING( @cSKUDescr, 21, 20), -- SOS39758  
                          @cO_Field05 = CAST(@nQtyAvailInUOM as NVARCHAR(16)), -- SOS39746  
                          @cO_Field01 = @cLOC  
  
                  -- SOS40003  
                  -- Prepare next screen var  
                  SELECT @nRecordCount = COUNT( 1)  
                  FROM dbo.LotxLocxID LLI (NOLOCK)  
                  WHERE StorerKey = @cStorer  
                    AND SKU = @cSKU  
                    AND LOC = @cLoc  
                    AND LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END) > 0  
  
                  IF @nRecordCount = 1  
                     SELECT  
                        @cI_Field08 = ID,  
                        @cO_Field08 = ID  
                     FROM dbo.LotxLocxID (NOLOCK)  
                     WHERE StorerKey = @cStorer  
                       AND SKU = @cSKU  
                       AND LOC = @cLoc  
                  ELSE  
                  BEGIN  
                     SET @cI_Field08 = ''  
                     SET @cO_Field08 = ''  
                  END  
               END  
               ELSE  
               BEGIN  
                  SET @cErrMsg = rdt.rdtgetmessage( 33, @cLangCode,'DSP') -- Qty Available = 0  
               END  
            END  
            ELSE -- @nRecordcount > 0  
            BEGIN  
               SET @cErrMsg = RTRIM(rdt.rdtgetmessage( 34, @cLangCode,'DSP')) -- No records (SKU)  
            END  
         END-- @b_success = 1  
      END-- IF @nFunc =  513 AND RTRIM(@cI_Field05) != ''  
   END-- IF @nInputKey = 1  
   ELSE IF @nInputKey = 0 -- Esc or No  
   BEGIN  
      SET @nScn = 804  
      SET @nStep = 1  
      SET @cLoc = ''  
  
     IF   @nFunc =  511  -- Move by Pallet ID  
          SET @cO_Field15 = rdt.rdtgetmessage( 14, @cLangCode,'DSP') -- Pallet ID:  
     ELSE  
          SET @cO_Field15 = rdt.rdtgetmessage( 15, @cLangCode,'DSP') -- Loc  
  
      SELECT @cO_Field01 = '',@cO_Field03 = '',@cO_Field04 = '', @cO_Field05 = ''  
      SELECT @cO_Field06 = '',@cO_Field07 = '',@cO_Field08 = '',@cO_Field09 = '', @cO_Field10 = ''  
      SELECT @cO_Field11 = '',@cO_Field12 = '',@cO_Field13 = '',@cO_Field14 = ''  
   END  
END-- @nStep = 2  
ELSE IF @nStep = 3  
BEGIN  
   IF @nInputKey = 1      -- Yes or Send  
   BEGIN  
      -- @cI_Field05 = Qty to Move  
      -- @cI_Field06 = LOC  
      -- @cI_Field08 = ID to move (for location consists of multiple IDs)  
  
      -- Rewrite for SOS40003 - start  
      IF @nFunc = 513 -- Move by SKU  
      BEGIN  
         -- Validate if QTY and LOC is key-in  
         IF (@cI_Field05 IS NULL OR @cI_Field05 = '') OR  
            (@cI_Field06 IS NULL OR @cI_Field06 = '')  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 13, @cLangCode, 'DSP') -- Enter Value!  
            GOTO Step3_Fail  
         END  
  
         -- Validate if QTY is numeric  
         IF ISNUMERIC( @cI_Field05) = 0  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 24, @cLangCode,'DSP') -- Numeric value!  
            GOTO Step3_Fail  
         END  
  
         -- Validate ToLOC is within same facility (move across facility not allowed)  
         SELECT @nRecordCount = COUNT( 1)  
         FROM dbo.LOC (NOLOCK)  
         WHERE LOC = @cI_Field06  
            AND Facility = @cFacility  
         IF @nRecordCount IS NULL OR @nRecordcount <= 0  
         BEGIN  
            SET @cErrMsg =  rdt.rdtgetmessage( 19, @cLangCode,'DSP') -- No records (LOC)  
            GOTO Step3_Fail  
         END  
  
         -- Validate if ID is valid  
         SELECT  
            @nRecordCount = COUNT( DISTINCT ID),  
            @nQtyAvailable = SUM( Qty - QtyAllocated - QtyPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END))  
         FROM dbo.LotxLocxID LLI (NOLOCK)  
         WHERE StorerKey = @cStorer  
            AND SKU = @cSKU  
            AND LOC = @cLoc  
            AND Qty - QtyAllocated - QtyPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END) > 0  
            AND ID = @cI_Field08  
         IF @nRecordCount IS NULL OR @nRecordCount <= 0  
         BEGIN  
            SET @cErrMsg =  rdt.rdtgetmessage( 36, @cLangCode,'DSP') -- No records (ID) -XX  
            GOTO Step3_Fail  
         END  
  
         -- Convert QTY in UOM to QTY in EA  
         SET @nQTYInUOM = CAST( @cI_Field05 AS INT)  
         SELECT @nQTY = CASE @cUOM  
            WHEN '1' THEN @nQTYInUOM * PACK.Pallet  
            WHEN '2' THEN @nQTYInUOM * PACK.CaseCnt  
            WHEN '3' THEN @nQTYInUOM * PACK.InnerPack  
            WHEN '4' THEN @nQTYInUOM * PACK.OtherUnit1  
            WHEN '5' THEN @nQTYInUOM * PACK.OtherUnit2  
            ELSE @nQTYInUOM END  
         FROM dbo.SKU SKU (NOLOCK)  
            INNER JOIN dbo.Pack Pack (NOLOCK) ON SKU.PackKey = Pack.PackKey  
         WHERE SKU.StorerKey = @cStorer  
            AND SKU.SKU = @cSKU  
  
         -- Validate if QTY is sufficient  
         IF @nQtyAvailable < @nQTY  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 32, @cLangCode,'DSP') -- Qty Move > Qty avail  
            GOTO Step3_Fail  
         END  
  
         -- Move  
         DECLARE cur_LLI CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            -- SELECT LLI.lot, LLI.ID, LLI.QTY, SKU.PackKey, Pack.PACKUOM3  
            SELECT LLI.lot, LLI.ID, LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END),   
                   SKU.PackKey, Pack.PACKUOM3 -- SOS# 174316  
            FROM dbo.LOTxLOCxID LLI (NOLOCK)  
               INNER JOIN dbo.SKU SKU (NOLOCK) ON LLI.StorerKey = SKU.Storerkey AND LLI.SKU = SKU.SKU  
               INNER JOIN dbo.Pack Pack (NOLOCK) ON SKU.PackKey = Pack.PackKey  
            WHERE LLI.StorerKey = @cStorer  
               AND LLI.SKU = @cSKU  
               AND LLI.LOC = @cLoc  
               AND LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END) > 0  
               AND LLI.ID = @cI_Field08  
            ORDER BY LLI.LOT, (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) -- SOS# 174316 -- LLI.QTY -- Try to move same lot and small QTY 1st  
         OPEN cur_LLI  
         FETCH NEXT FROM cur_LLI INTO @cLot, @cID, @nLLIQty, @cPackKey, @cPackUOM3  
  
         SET @nQTYRemain = @nQTY  
         WHILE @@FETCH_STATUS <> -1 AND @nQTYRemain > 0  
         BEGIN  
            IF @nLLIQTY >= @nQTYRemain  
               SET @nQTYToMove = @nQTYRemain  
            ELSE  
               SET @nQTYToMove = @nLLIQTY  
  
            EXEC dbo.nspItrnAddMove  
               NULL,         -- @n_ItrnSysId    int  
               @cStorer,     -- @c_StorerKey    NVARCHAR(15)  
               @cSKU,        -- @c_Sku          NVARCHAR(20)  
               @cLot,        -- @c_Lot          NVARCHAR(10)  
               @cLoc,        -- @c_FromLoc      NVARCHAR(10)  
               @cID,         -- @c_FromID       NVARCHAR(18)  
               @cI_Field06,  -- @c_ToLoc        NVARCHAR(10)  
               @cID,         -- @c_ToID         NVARCHAR(18)  
               '',           -- @c_Status       NVARCHAR(10)  
               '',           -- @c_lottable01   NVARCHAR(18)  
               '',           -- @c_lottable02   NVARCHAR(18)  
               '',           -- @c_lottable03   NVARCHAR(18)  
               '',           -- @d_lottable04   datetime  
               '',           -- @d_lottable05   datetime  
               0,            -- @n_casecnt      int  
               0,            -- @n_innerpack    int  
               @nQTYToMove,  -- @n_qty          int  
               0,            -- @n_pallet       int  
               0,            -- @f_cube         float  
               0,            -- @f_grosswgt     float  
               0,            -- @f_netwgt       float  
               0,            -- @f_otherunit1   float  
               0,            -- @f_otherunit2   float  
               '',           -- @c_SourceKey    NVARCHAR(20)  
               'rdt_fncMove',-- @c_SourceType   NVARCHAR(30)  
               @cPackKey,    -- @c_PackKey      NVARCHAR(10)  
               @cPackUOM3,   -- @c_UOM          NVARCHAR(10)  
               1,            -- @b_UOMCalc      int  
               '',           -- @d_EffectiveDate datetime  
               '',           -- @c_itrnkey      NVARCHAR(10)   OUTPUT  
               @b_Success OUTPUT, -- @b_Success      int        OUTPUT  
               @n_err OUTPUT,     -- @n_err          int        OUTPUT  
               @c_errmsg OUTPUT   -- @c_errmsg       NVARCHAR(250)  OUTPUT  
  
            IF @b_success = 1  
               SET @nQTYRemain = @nQTYRemain - @nQTYToMove  
            ELSE  
               SET @cErrMsg = cast (@b_success AS NVARCHAR(3))  
  
            FETCH NEXT FROM cur_LLI INTO @cLot, @cID, @nLLIQty, @cPackKey, @cPackUOM3  
         END  
         CLOSE cur_LLI  
         DEALLOCATE cur_LLI  
  
         -- Go to next screen  
         SET @nScn = 805  
         SET @nStep = 2  
  
         -- Prepare next screen variable  
         SET @cSKU = ''  
         SELECT  
            @cO_Field04 = COUNT( DISTINCT SKU.SKU),  
            @nQtyAvailInUOM = SUM(  
               CASE @cUOM  
                  WHEN '1' THEN FLOOR( (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked  
                                 - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) / Pack.Pallet)  
                  WHEN '2' THEN FLOOR( (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked  
                                 - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) / Pack.CaseCnt)  
                  WHEN '3' THEN FLOOR( (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked  
                                 - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) / Pack.InnerPack)  
                  WHEN '4' THEN FLOOR( (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked  
                  - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) / Pack.OtherUnit1)  
                  WHEN '5' THEN FLOOR( (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked  
                                 - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) / Pack.OtherUnit2)  
                  ELSE (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked  
                                - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END))  
               END)  
         FROM dbo.LOTxLOCxID LLI (NOLOCK)  
            INNER JOIN dbo.SKU SKU (NOLOCK) ON LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU  
            INNER JOIN dbo.Pack Pack (NOLOCK) ON SKU.PackKey = Pack.PackKey  
         WHERE LLI.StorerKey = @cStorer  
            AND LLI.LOC = @cLOC   
  
         IF @@ROWCOUNT = 0  
            SET @cErrMsg = 'No Records found'  
  
         SELECT @cO_Field02 = CASE @nFunc WHEN 512 THEN 'To Loc:'  
                                          WHEN 513 THEN 'SKU:'  
                              END  
  
         SET @cO_Field04  = 'SKUs ' + @cO_Field04 + ' Qty ' + CAST( @nQtyAvailInUOM AS NVARCHAR(10)) -- SOS39746  
         SET @cO_Field11  = 'Loc: ' + @cLoc  
  
         SELECT  
            @cO_Field01 = '',  
            @cO_Field03 = '',  
            @cO_Field05 = '', @cO_Field06 = '',  
            @cO_Field07 = '', @cO_Field08 = '',  
            @cO_Field09 = '', @cO_Field10 = '',  
                              @cO_Field12 = '',  
            @cO_Field13 = '', @cO_Field14 = ''  
      END  
      -- Rewrite for SOS40003 - end  
   END-- IF @nInputKey = 1  
   ELSE IF @nInputKey = 0 -- Esc or No  
   BEGIN  
      SET @nScn = 805  
      SET @nStep = 2  
      SET @cSKU = ''  
  
      SELECT @cO_Field02 = CASE @nFunc WHEN 512 THEN 'To Loc:'  
                                       WHEN 513 THEN 'SKU:'  
                           END  
  
      -- SOS39746  
      SELECT  
         @cO_Field04 = COUNT( DISTINCT SKU.SKU),  
         @nQtyAvailInUOM = SUM(  
            CASE @cUOM  
               WHEN '1' THEN FLOOR( (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked  
                              - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) / Pack.Pallet)  
               WHEN '2' THEN FLOOR( (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked  
                              - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) / Pack.CaseCnt)  
               WHEN '3' THEN FLOOR( (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked  
                              - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) / Pack.InnerPack)  
               WHEN '4' THEN FLOOR( (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked  
                              - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) / Pack.OtherUnit1)  
               WHEN '5' THEN FLOOR( (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked  
                              - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) / Pack.OtherUnit2)  
               ELSE (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked  
                             - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END))  
           END)  
         FROM dbo.LOTxLOCxID LLI (NOLOCK)  
            INNER JOIN dbo.SKU SKU (NOLOCK) ON LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU  
            INNER JOIN dbo.Pack Pack (NOLOCK) ON SKU.PackKey = Pack.PackKey  
         WHERE LLI.StorerKey = @cStorer  
            AND LLI.LOC = @cLOC   
  
      IF @nRecordcount = 0  
      BEGIN  
          SET @cErrMsg = 'No Records found'  
      END  
      SET @cO_Field13  = ''  
      SET @cO_Field11  = 'Loc: ' + @cLoc  
      SET @cO_Field04  = 'SKUs ' + @cO_Field04 + ' Qty ' + CAST( @nQtyAvailInUOM AS NVARCHAR(10)) -- SOS39746  
  
      SELECT @cO_Field01 = '',@cO_Field03 = '', @cO_Field05 = ''  
      SELECT @cO_Field06 = '',@cO_Field07 = '',@cO_Field08 = '', @cO_Field09 = '',@cO_Field10 = ''  
      SELECT @cO_Field12 = '',@cO_Field14 = ''  
   END -- IF @nInputKey = 0  
  
Step3_Fail:  
  
END -- Step = 3  
  
BEGIN  
   UPDATE RDTMOBREC WITH (ROWLOCK) SET 
   EditDate = GETDATE(), 
   ErrMsg = @cErrMsg   , Func = @nFunc,  
   Step = @nStep           , Scn = @nScn,  
   V_LOC = @cLoc           , V_SKU = @cSKU,  
   O_Field01 = @cO_Field01 , O_Field02 =  @cO_Field02,  
   O_Field03 = @cO_Field03 , O_Field04 =  @cO_Field04,  
   O_Field05 = @cO_Field05 , O_Field06 =  @cO_Field06,  
   O_Field07 = @cO_Field07 , O_Field08 =  @cO_Field08,  
   O_Field09 = @cO_Field09 , O_Field10 =  @cO_Field10,  
   O_Field11 = @cO_Field11 , O_Field12 =  @cO_Field12,  
   O_Field13 = @cO_Field13 , O_Field14 =  @cO_Field14,  
   O_Field15 = @cO_Field15 ,  
   I_Field01 = '', I_Field02 = ''  
   WHERE Mobile = @nMobile  
  
END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc : isp_VAS_Update_Status                                  */
/* Creation Date:                                                       */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/* Purpose: Execute Kit from VAS_Plan                                   */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_VAS_Update_Status]
   @n_Test_VASDemandKey  BIGINT = 0,
   @b_Debug              INT = 0
AS
BEGIN
   SET NOCOUNT ON

   -- VAS_Demand.Status
   --  WAIT         : Waiting for materials
   --  OPEN         : Ready for Planning
   --  Planning     : In Planning
   --  In-Progreass : Kitting Order Created
   --  Closed       : Kitting Completed

   DECLARE
       @n_VASDemandKey           BIGINT,
       @c_StorerKey              NVARCHAR(15),
       @c_RepackCode             NVARCHAR(20),
       @n_DemandQty              INT,
       @c_SKU                    NVARCHAR(20),
       @c_ComponentSku           NVARCHAR(20),
       @c_BomNotes               NVARCHAR(4000),
       @n_ComponentQty           INT,
       @n_ParentQty              INT,
       @c_SKU_SUSR4              NVARCHAR(18),
       @c_BOMReady               CHAR(1) = 'N',
       @c_FGReady                CHAR(1) = 'N',
       @n_PM_Requied_Qty         INT = 0,
       @n_Component_Requied_Qty  INT = 0,
       @c_ComponentReady         CHAR(1) = 'N',
       @c_PIReady                CHAR(1) = 'N',
       @c_PMReady                CHAR(1) = 'N',
       @n_QtyAvailable           INT = 0


   DECLARE CUR_VAS_DEMAND CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT VASDemandKey, StorerKey, RepackCode, Qty
   FROM VAS_Demand WITH (NOLOCK)
   WHERE [Status]='WAIT'
   AND   VASDemandKey = CASE WHEN @n_Test_VASDemandKey > 0 THEN @n_Test_VASDemandKey ELSE VASDemandKey END


   OPEN CUR_VAS_DEMAND

   FETCH FROM CUR_VAS_DEMAND INTO @n_VASDemandKey, @c_StorerKey, @c_RepackCode, @n_DemandQty

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_SKU = @c_RepackCode

      IF @b_Debug = 1
      BEGIN
         PRINT ''
         PRINT 'RepackCode: ' +  @c_RepackCode
      END

      -- Initialize variable
      SET @c_BOMReady = 'N'


      IF NOT EXISTS (SELECT 1 FROM BillOfMaterial AS bom WITH(NOLOCK)
                     WHERE bom.Storerkey = @c_StorerKey
                     AND   bom.Sku = @c_SKU)
      BEGIN
         SET @c_BOMReady = 'N'
         SET @c_ComponentReady = 'N'
         SET @c_PIReady = 'N'
         SET @c_PMReady = 'N'
      END
      ELSE
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM SKU WITH (NOLOCK)
                        WHERE StorerKey = @c_StorerKey
                        AND Sku = @c_SKU)
         BEGIN
            SET @c_BOMReady = 'N'
            SET @c_FGReady  = 'N'
         END
         ELSE
         BEGIN
            SET @c_BOMReady = 'Y'
            SET @c_FGReady  = 'Y'

            SET @c_PIReady = 'Y'
            SET @c_PMReady = 'Y'
            SET @c_ComponentReady = 'Y'

            DECLARE CUR_COMPONENTS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT ComponentSku, Notes, ParentQty, Qty
            FROM BillOfMaterial WITH (NOLOCK)
            WHERE Storerkey = @c_StorerKey
            AND   Sku = @c_SKU
            ORDER BY [Sequence]

            OPEN CUR_COMPONENTS

            FETCH FROM CUR_COMPONENTS INTO @c_ComponentSku, @c_BomNotes, @n_ParentQty, @n_ComponentQty

            WHILE @@FETCH_STATUS = 0
            BEGIN
               SET @c_SKU_SUSR4 = ''

               SELECT @c_SKU_SUSR4 = SUSR4
               FROM SKU AS s WITH(NOLOCK)
               WHERE s.StorerKey = @c_StorerKey
               AND s.Sku = @c_ComponentSku

               IF @b_Debug = 1
               BEGIN
                  PRINT 'ComponentSku: ' + @c_ComponentSku + ' @c_SKU_SUSR4: ' + @c_SKU_SUSR4
                  PRINT 'DemandQty: ' + CAST(ISNULL(@n_DemandQty,0) AS VARCHAR) + ' ParentQty: ' + CAST(ISNULL(@n_ParentQty,0) AS VARCHAR)
                  PRINT 'ComponentQty: ' + CAST(ISNULL(@n_ComponentQty,0) AS VARCHAR)
               END

               IF @c_SKU_SUSR4 <> 'P'
               BEGIN
                  SET @n_PM_Requied_Qty = 0
                  SET @n_Component_Requied_Qty = CAST(((@n_DemandQty * 1.00) / @n_ParentQty) AS FLOAT) * @n_ComponentQty

               END
               ELSE
               BEGIN
                  SET @n_PM_Requied_Qty = CAST(((@n_DemandQty * 1.00) / @n_ParentQty) AS FLOAT) * @n_ComponentQty
                  SET @n_Component_Requied_Qty = 0
               END

               IF ISNULL(@c_BomNotes,'') = '' AND @c_PIReady = 'Y'
               BEGIN
                  SET @c_PIReady = 'N'
               END

               SET @n_QtyAvailable = 0

               SELECT @n_QtyAvailable = SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyPickInProcess)
               FROM dbo.LOTxLOCxID LLI (NOLOCK)
               INNER JOIN dbo.LOC LOC (NOLOCK) ON (LLI.Loc = LOC.Loc AND LOC.LocationFlag <> 'HOLD' AND LOC.STATUS='OK')
               INNER JOIN dbo.LOT LOT (NOLOCK) ON (LLI.Lot = LOT.Lot) AND LOT.STATUS='OK'
               INNER JOIN dbo.ID ID (NOLOCK) ON (LLI.Id = ID.Id) AND ID.STATUS='OK'
               WHERE LLI.StorerKey = @c_StorerKey
               AND LLI.SKU = @c_ComponentSku

               SET @n_QtyAvailable = ISNULL(@n_QtyAvailable,0)
               SET @n_PM_Requied_Qty = ISNULL(@n_PM_Requied_Qty,0)

               IF @b_Debug = 1
               BEGIN
                  PRINT 'ComponentSku: ' + @c_ComponentSku + ' @n_QtyAvailable: ' + CAST(ISNULL(@n_QtyAvailable,0) AS VARCHAR)
                  PRINT 'PM_Requied_Qty: ' + CAST(ISNULL(@n_PM_Requied_Qty,0) AS VARCHAR) + ' Component_Requied_Qty: ' + CAST(ISNULL(@n_Component_Requied_Qty,0) AS VARCHAR)
               END

               IF @c_SKU_SUSR4 = 'P'
               BEGIN
                  IF @n_QtyAvailable < @n_PM_Requied_Qty AND @c_PMReady = 'Y'
                  BEGIN
                     SET @c_PMReady = 'N'
                  END
               END

               IF @n_QtyAvailable < @n_Component_Requied_Qty AND @c_ComponentReady = 'Y'
               BEGIN
                  SET @c_ComponentReady = 'N'
               END

               FETCH FROM CUR_COMPONENTS INTO @c_ComponentSku, @c_BomNotes, @n_ParentQty,
                                         @n_ComponentQty
            END

            CLOSE CUR_COMPONENTS
            DEALLOCATE CUR_COMPONENTS
         END -- IF SKU EXISTS
      END -- IF BOM EXISTS

      UPDATE VAS_Demand
         SET SKUReady=@c_FGReady,
             ComponentReady = @c_ComponentReady,
             PMReady = @c_PMReady,
             PIReady = @c_PiReady,
             BOMReady = @c_BOMReady,
             [Status] =CASE WHEN  @c_ComponentReady='Y' AND @c_PMReady='Y' AND @c_PiReady='Y' AND @c_BOMReady='Y'
                            THEN 'OPEN' ELSE [Status]
                       END,
             EditDate = GETDATE(),
             EditWho = SUSER_SNAME()
      WHERE VASDemandKey = @n_VASDemandKey

      FETCH FROM CUR_VAS_DEMAND INTO @n_VASDemandKey, @c_StorerKey, @c_RepackCode, @n_DemandQty
   END

   CLOSE CUR_VAS_DEMAND
   DEALLOCATE CUR_VAS_DEMAND

END -- Procedure

GO
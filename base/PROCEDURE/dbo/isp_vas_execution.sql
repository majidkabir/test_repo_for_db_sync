SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc : isp_VAS_Execution                                      */
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

CREATE PROC [dbo].[isp_VAS_Execution] (
   @b_Success INT OUTPUT,
   @n_Err     INT OUTPUT,
   @c_ErrMsg  NVARCHAR(250)  OUTPUT
   )
AS
BEGIN
   DECLARE  @n_VASPlanKey         BIGINT,
            @c_StorerKey          NVARCHAR(15),
            @c_SKU                NVARCHAR(20),
            @n_AllocatedQty       INT = 0,
            @n_VASDemandKey       BIGINT,
            @c_KitKey             NVARCHAR(10) = '',
            @c_PackKey            NVARCHAR(10) = '',
            @c_UOM3               NVARCHAR(10) = '',
            @c_ComponentSku       NVARCHAR(20) = '',
            @n_ComponentQty       INT = 0,
            @n_ParentQty          INT = 0,
            @n_KitQty             INT = 0

    --Cursor by VASPlanKey+SKU
    DECLARE CUR_VAS_PLAN CURSOR LOCAL READ_ONLY READ_ONLY FOR
    SELECT VASPlanKey,StorerKey,RepackCode,AllocatedQty,VASDemandKey
    FROM VAS_Plan WITH (NOLOCK)
    WHERE PlanDate=CONVERT(VARCHAR,DATEADD(DD,2,GETDATE()),111)

   OPEN CUR_VAS_PLAN

   FETCH NEXT FROM CUR_VAS_PLAN INTO @n_VASPlanKey,@c_StorerKey,@c_SKU,@n_AllocatedQty,@n_VASDemandKey
   WHILE @@FETCH_STATUS=0
   BEGIN
      --Get KitKey
      EXEC nspg_GetKey
         @KeyName = 'KITTING',
         @fieldlength = 10,
         @keystring = @c_KitKey OUTPUT,
         @b_Success = @b_Success OUTPUT,
         @n_err = @n_err OUTPUT,
         @c_errmsg = @c_errmsg OUTPUT,
         @b_resultset = 1,
         @n_batch = 1

      --Insert KIT
      INSERT INTO KIT (KITKey, StorerKey, ToStorerKey, [Type], OpenQty,[Status])
      VALUES (@c_KitKey, @c_StorerKey, @c_StorerKey, 'VAS' ,0, '0')


      SELECT @c_PackKey = P.PackKey,
             @c_UOM3    = P.PackUOM3
      FROM PACK AS p WITH(NOLOCK)
      JOIN SKU AS s WITH(NOLOCK) ON s.PackKey = p.PackKey
      WHERE S.StorerKey = @c_StorerKey
      AND S.Sku = @c_SKU

      --Parent SKU Type=T
      INSERT INTO KITDetail (KITKey, KITLineNumber, [Type], StorerKey, Sku, ExpectedQty, PackKey, UOM)
      VALUES(@c_KitKey, '00001', 'T', @c_StorerKey, @c_SKU, @n_AllocatedQty, @c_PackKey, @c_UOM3)

      --Get ComponentSku from BOM
      DECLARE CUR_Component_SKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT ComponentSku, Qty, ParentQty
      FROM BillOfMaterial WITH (NOLOCK)
      WHERE Storerkey= @c_StorerKey
      AND Sku = @c_SKU

      OPEN CUR_Component_SKU

      FETCH FROM CUR_Component_SKU INTO @c_ComponentSku, @n_ComponentQty, @n_ParentQty

      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @n_KitQty = (@n_AllocatedQty / @n_ParentQty) * @n_ComponentQty

         SELECT @c_PackKey = P.PackKey,
                @c_UOM3    = P.PackUOM3
         FROM PACK AS p WITH(NOLOCK)
         JOIN SKU AS s WITH(NOLOCK) ON s.PackKey = p.PackKey
         WHERE S.StorerKey = @c_StorerKey
         AND S.Sku = @c_ComponentSku

         --Component SKU Type=F
         INSERT INTO KITDetail (KITKey, KITLineNumber, [Type], StorerKey, Sku,ExpectedQty, PackKey, UOM)
         VALUES(@c_KitKey, '00001', 'F', @c_StorerKey, @c_ComponentSku, @n_KitQty, @c_PackKey, @c_UOM3)

         FETCH FROM CUR_Component_SKU INTO @c_ComponentSku, @n_ComponentQty, @n_ParentQty


      END

      CLOSE CUR_Component_SKU
      DEALLOCATE CUR_Component_SKU

      UPDATE VAS_Demand SET STATUS='Kitting' WHERE VASDemandKey=@n_VASDemandKey
      UPDATE VAS_Plan SET KITKey=@c_KitKey WHERE VASPlanKey=@n_VASPlanKey


   FETCH NEXT FROM CUR_VAS_PLAN INTO @n_VASPlanKey,@c_StorerKey,@c_SKU,@n_AllocatedQty,@n_VASDemandKey
   END
   CLOSE CUR_VAS_PLAN
   DEALLOCATE CUR_VAS_PLAN
END

GO
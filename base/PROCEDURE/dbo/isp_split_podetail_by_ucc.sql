SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Stored Procedure: isp_Split_PODetail_By_UCC                                */
/* Creation Date: 12-Mar-2019                                                 */
/* Copyright: LFL                                                             */
/* Written by: Shong                                                          */
/*                                                                            */
/* Purpose: Split PO Line by UCC, Update PO Lotttable10 = UCC No              */
/* Called By:                                                                 */
/*                                                                            */
/* PVCS Version: 1.2                                                          */
/*                                                                            */
/* Version: 1.0                                                               */
/*                                                                            */
/* Data Modifications:                                                        */
/*                                                                            */
/* Updates:                                                                   */
/* Date         Author    Rev   Purposes                                      */
/* 12-Mar-2019  Shong     1.0   Initial Version                               */
/* 26-Apr-2019  Leong     1.1   INC0680023 - Cater 1 UCC = Multiple Sku.      */
/* 08-May-2019  YokeBeen  1.2   WMS#8973 Add logics to set valid data base on */  
/*                              CODELKUP.Listname = "NIKEPOTYPE" into PODetail*/
/*                              table. - (YokeBeen01)                         */  
/* 10-May-2019  JovineNg  1.3   Add Storerkey as parameter  (JN01)            */
/******************************************************************************/

CREATE PROC [dbo].[isp_Split_PODetail_By_UCC]
 (  @c_POKey            NVARCHAR(18),
    @c_Storerkey        NVARCHAR(15),           --(JN01)
    @b_Success          INT = 1 OUTPUT,
    @n_Err              INT = 0 OUTPUT,
    @c_ErrMsg           NVARCHAR(250) = '' OUTPUT
 )
AS
BEGIN
   SET NOCOUNT ON

   DECLARE @c_POLineNumber     NVARCHAR(5)
          --,@c_StorerKey        NVARCHAR(15)      --(JN01)
          ,@c_Sku              NVARCHAR(20)
          ,@n_QtyOrdered       INT
          ,@n_Total_UCC_Qty    INT
          ,@n_NoOfUCC          INT
          ,@c_UCCNO            NVARCHAR(20)
          ,@c_SourceKey        NVARCHAR(30)
          ,@n_UCCQty           INT
          ,@c_Status           NVARCHAR(1)
          ,@n_LastPOLine       INT
          ,@c_NewPOLineNumber  NVARCHAR(5)
          ,@n_Continue         INT = 1
          ,@n_StartTCnt        INT
          ,@c_Listname         NVARCHAR(10)    -- (YokeBeen01)
          ,@c_Lottable10       NVARCHAR(30)    -- (YokeBeen01)
          ,@c_Short            NVARCHAR(10)    -- (YokeBeen01)

   SET @c_Listname             = 'NIKEPOTYPE'  -- (YokeBeen01)
   SET @c_Lottable10           = ''            -- (YokeBeen01)
   SET @c_Short                = ''            -- (YokeBeen01)

   SELECT @n_StartTCnt=@@TRANCOUNT , @n_Continue=1

   IF EXISTS (SELECT 1 FROM RECEIPT AS R WITH(NOLOCK)
               WHERE R.POKey = @c_POKey)
   BEGIN
      SELECT @n_Continue = 3
      SELECT @c_ErrMsg = CONVERT(char(250),@n_Err), @n_Err=500151
      SELECT @c_ErrMsg = 'NSQL' + CONVERT(char(5),@n_Err) + ': Split PO Detail Fail, PO already populate to Receipt (isp_Split_PODetail_By_UCC)'
      RETURN
   END

   -- (YokeBeen01) - Start
   -- Retrieve valid value to be assigned for PODetail.Lottable10.
   SELECT @c_Short = CODELKUP.Short
     FROM  PO WITH (NOLOCK)
     JOIN  CODELKUP WITH (NOLOCK) ON (CODELKUP.StorerKey = PO.StorerKey
                                 AND CODELKUP.Listname = @c_Listname
                                 AND CODELKUP.Code = SUBSTRING(PO.ExternPOKey,1,2)
                                 AND CODELKUP.Code2 = PO.POType)
    WHERE PO.Storerkey = @c_StorerKey
      AND PO.POKey = @c_POKey
   -- (YokeBeen01) - End


   DECLARE CUR_PO_DETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT POKey
         ,POLineNumber
         ,StorerKey
         ,Sku
         ,QtyOrdered
   FROM   PODETAIL WITH (NOLOCK)
   WHERE  POKey = @c_POKey
   AND  ( Lottable10 = '' OR Lottable10 IS NULL )
   AND    QtyReceived = 0

   OPEN CUR_PO_DETAIL
   FETCH FROM CUR_PO_DETAIL INTO @c_POKey, @c_POLineNumber, @c_StorerKey, @c_Sku, @n_QtyOrdered

   WHILE @@FETCH_STATUS=0
   BEGIN
      SET @c_SourceKey =  @c_POKey + @c_POLineNumber

      SELECT @n_Total_UCC_Qty = SUM(Qty),
             @n_NoOfUCC = COUNT(1),
             @c_UCCNo = MAX(UCCNO)
       FROM  UCC WITH (NOLOCK)
      WHERE Storerkey = @c_StorerKey
        AND SKU = @c_Sku
        AND Sourcekey = @c_SourceKey
        AND [Status] = '0'

      IF @n_Total_UCC_Qty =  @n_QtyOrdered
      BEGIN
         IF @n_NoOfUCC > 1
         BEGIN
            -- PRINT 'Split UCC..'
            DECLARE CUR_UCC_LINES CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT UCCNo, Qty
              FROM UCC WITH (NOLOCK)
             WHERE Storerkey = @c_StorerKey
               AND SKU = @c_Sku
               AND Sourcekey = @c_SourceKey
               AND [Status] = '0'

            OPEN CUR_UCC_LINES
            FETCH FROM CUR_UCC_LINES INTO @c_UCCNo, @n_UCCQty

            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- (YokeBeen01) - Start
               -- Assigned valid value for PODetail.Lottable10.
               IF @c_Short = ('UCCNum')
               BEGIN
                  SET @c_Lottable10 = @c_UCCNo
               END
               ELSE
               BEGIN -- When No setup in CODELKUP
                  SET @c_Lottable10 = ''
               END
               -- (YokeBeen01) - End
                  
               -- If Qty Ordered > UCC Qty, Split Line
               IF @n_QtyOrdered > @n_UCCQty
               BEGIN
                  SET @n_LastPOLine = 0

                  SELECT @n_LastPOLine = CAST(MAX(PD.POLineNumber) AS INT)
                    FROM PODETAIL AS PD WITH (NOLOCK)
                   WHERE PD.POKey = @c_POKey

                  SET @c_NewPOLineNumber = RIGHT('0000' +  CAST(@n_LastPOLine + 1 AS VARCHAR(5)), 5)

                  INSERT INTO PODETAIL (POKey, POLineNumber, StorerKey, PODetailKey,
                                       ExternPOKey, ExternLineNo, MarksContainer, Sku,
                                       SKUDescription, ManufacturerSku, RetailSku, AltSku,
                                       QtyOrdered, QtyAdjusted, QtyReceived, PackKey,
                                       UnitPrice, UOM, Notes, POLineStatus, Facility,
                                       shortcode, Best_bf_Date, Lottable01, Lottable02,
                                       Lottable03, Lottable04, Lottable05, UserDefine01,
                                       UserDefine02, UserDefine03, UserDefine04,
                                       UserDefine05, UserDefine06, UserDefine07,
                                       UserDefine08, UserDefine09, UserDefine10, ToId,
                                       Lottable06, Lottable07, Lottable08, Lottable09,
                                       Lottable10, Lottable11, Lottable12, Lottable13,
                                       Lottable14, Lottable15, Channel)
                  SELECT POKey, @c_NewPOLineNumber, StorerKey, PODetailKey,
                               ExternPOKey, ExternLineNo, MarksContainer, Sku,
                               SKUDescription, ManufacturerSku, RetailSku, AltSku,
                               QtyOrdered = @n_UCCQty,
                               QtyAdjusted = 0, QtyReceived, PackKey,
                               UnitPrice, UOM, Notes, POLineStatus, Facility,
                               shortcode, Best_bf_Date, Lottable01,
                               Lottable02, Lottable03, Lottable04, Lottable05,
                               UserDefine01,
                               UserDefine02, UserDefine03, UserDefine04,
                               UserDefine05, UserDefine06, UserDefine07,
                               UserDefine08, UserDefine09, UserDefine10, ToId,
                               Lottable06, Lottable07, Lottable08, Lottable09,
                               Lottable10 = @c_Lottable10, Lottable11, Lottable12, Lottable13,   -- (YokeBeen10)
                               Lottable14, Lottable15, Channel
                  FROM  PODETAIL AS PD WITH(NOLOCK)
                  WHERE PD.POKey = @c_POKey
                  AND   PD.POLineNumber = @c_POLineNumber

                  IF @@ERROR = 0
                  BEGIN
                     UPDATE UCC
                        SET Sourcekey = @c_POKey + @c_NewPOLineNumber,
                            EditDate = GETDATE(),
                            EditWho = SUSER_SNAME()
                      WHERE UCCNo = @c_UCCNO
                        AND Storerkey = @c_StorerKey
                        AND SKU = @c_Sku -- INC0680023

                     IF @@ERROR <> 0
                     BEGIN
                        SELECT @n_Continue = 3
                        SELECT @c_ErrMsg = CONVERT(char(250),@n_Err), @n_Err=500152
                        SELECT @c_ErrMsg = 'NSQL' + CONVERT(char(5),@n_Err) + ': Update UCC Failed (isp_Split_PODetail_By_UCC)'
                     END
                     ELSE
                     BEGIN
                        UPDATE PODETAIL WITH (ROWLOCK)
                           SET QtyOrdered = QtyOrdered - @n_UCCQty,
                               EditDate = GETDATE(),
                               EditWho = SUSER_SNAME()
                         WHERE POKey = @c_POKey
                           AND POLineNumber = @c_POLineNumber

                        IF @@ERROR <> 0
                        BEGIN
                           SELECT @n_Continue = 3
                           SELECT @c_ErrMsg = CONVERT(char(250),@n_Err), @n_Err=500153
                           SELECT @c_ErrMsg = 'NSQL' + CONVERT(char(5),@n_Err) + ': Update PODetail Failed (isp_Split_PODetail_By_UCC)'
                        END
                     END

                     SET @n_QtyOrdered = @n_QtyOrdered - @n_UCCQty
                  END -- If split line sucessfull (@@ERROR = 0)
               END -- -- If Qty Ordered > UCC Qty, Split Line
               ELSE
               BEGIN
                  -- Last Line, Only update the original line
                  UPDATE PODETAIL WITH (ROWLOCK)
                     SET Lottable10 = @c_Lottable10,  -- (YokeBeen01)
                         EditDate = GETDATE(),
                         EditWho = SUSER_SNAME()
                   WHERE POKey = @c_POKey
                     AND POLineNumber = @c_POLineNumber

                  IF @@ERROR <> 0
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_ErrMsg = CONVERT(char(250),@n_Err), @n_Err=500154
                     SELECT @c_ErrMsg = 'NSQL' + CONVERT(char(5),@n_Err) + ': Update PODetail Failed (isp_Split_PODetail_By_UCC)'
                  END
                  SET @n_QtyOrdered = @n_QtyOrdered - @n_UCCQty
               END

               IF @n_QtyOrdered <= 0
                  BREAK

               FETCH FROM CUR_UCC_LINES INTO @c_UCCNo, @n_UCCQty
            END
            CLOSE CUR_UCC_LINES
            DEALLOCATE CUR_UCC_LINES
         END  -- IF @n_NoOfUCC > 1
         ELSE
         BEGIN  -- IF @n_NoOfUCC = 1
            -- PRINT 'Only 1 UCC'

            -- (YokeBeen01) - Start
            -- Assigned valid value for PODetail.Lottable10.
            IF @c_Short = ('UCCNum')
            BEGIN
               SET @c_Lottable10 = @c_UCCNo
            END
            ELSE
            BEGIN -- When No setup in CODELKUP
               SET @c_Lottable10 = ''
            END
            -- (YokeBeen01) - End

            UPDATE PODETAIL WITH (ROWLOCK)
               SET Lottable10 = @c_Lottable10,   -- (YokeBeen01)
                   TrafficCop = NULL,
                   EditDate = GETDATE()
             WHERE POKey = @c_POKey
               AND POLineNumber = @c_POLineNumber
         END
      END

      FETCH FROM CUR_PO_DETAIL INTO @c_POKey, @c_POLineNumber, @c_StorerKey, @c_Sku, @n_QtyOrdered
   END

   CLOSE CUR_PO_DETAIL
   DEALLOCATE CUR_PO_DETAIL

Quit:
   WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN TRAN;

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_Split_PODetail_By_UCC'
        RAISERROR (@c_errmsg, 16, 1) WITH SETERROR
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END -- Procedure

GO
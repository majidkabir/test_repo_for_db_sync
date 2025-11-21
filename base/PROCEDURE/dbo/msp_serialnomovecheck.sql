SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/**************************************************************************/
/* Stored Procedure: msp_SerialNoMoveCheck                                */
/* Creation Date:                                                         */
/* Copyright: Mearsk                                                      */
/* Written by:                                                            */
/*                                                                        */
/* Purpose: Generic SerialNo Move update                                  */
/*                                                                        */
/* Called By:                                                             */
/*                                                                        */
/* Version: V2.0                                                          */
/*                                                                        */
/* Data Modifications:                                                    */
/*                                                                        */
/* Updates:                                                               */
/* Date         Author    Ver. Purposes                                   */
/**************************************************************************/
CREATE   PROCEDURE [dbo].[msp_SerialNoMoveCheck]
     @c_ItrnKey      NVARCHAR(10)
   , @c_StorerKey    NVARCHAR(15)
   , @c_Sku          NVARCHAR(20)
   , @c_Lot          NVARCHAR(10)
   , @c_Fromloc      NVARCHAR(10)
   , @c_FromID       NVARCHAR(18)
   , @c_ToLoc        NVARCHAR(10)
   , @c_ToID         NVARCHAR(18)
   , @c_Packkey      NVARCHAR(10)
   , @c_Status       NVARCHAR(10)
   , @n_Casecnt      INT       -- Casecount being inserted
   , @n_Innerpack    INT       -- innerpacks being inserted
   , @n_Qty          INT       -- QTY (Most important) being inserted
   , @n_Pallet       INT       -- pallet being inserted
   , @f_Cube         FLOAT     -- cube being inserted
   , @f_Grosswgt     FLOAT     -- grosswgt being inserted
   , @f_Netwgt       FLOAT     -- netwgt being inserted
   , @f_Otherunit1   FLOAT     -- other units being inserted.
   , @f_Otherunit2   FLOAT     -- other units being inserted too.
   , @c_Lottable01   NVARCHAR(18) = ''
   , @c_Lottable02   NVARCHAR(18) = ''
   , @c_Lottable03   NVARCHAR(18) = ''
   , @d_Lottable04   DATETIME     = NULL
   , @d_Lottable05   DATETIME     = NULL
   , @c_Lottable06   NVARCHAR(30) = ''   
   , @c_Lottable07   NVARCHAR(30) = ''   
   , @c_Lottable08   NVARCHAR(30) = ''   
   , @c_Lottable09   NVARCHAR(30) = ''   
   , @c_Lottable10   NVARCHAR(30) = ''   
   , @c_Lottable11   NVARCHAR(30) = ''   
   , @c_Lottable12   NVARCHAR(30) = ''   
   , @d_Lottable13   DATETIME = NULL     
   , @d_Lottable14   DATETIME = NULL     
   , @d_Lottable15   DATETIME = NULL     
   , @b_Success      INT        OUTPUT
   , @n_Err          INT        OUTPUT
   , @c_Errmsg       NVARCHAR(250)  OUTPUT
   , @c_MoveRefKey   NVARCHAR(10)  = ''     
   , @c_Channel      NVARCHAR(20) = ''      
   , @n_Channel_ID   BIGINT = 0 OUTPUT      
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
      @c_SerialNoCapture NVARCHAR(1) = ''
     ,@c_SerialNoKey     NVARCHAR(10) = ''
     ,@n_Continue        INT = 1

   SELECT @c_SerialNoCapture = SerialNoCapture 
   FROM dbo.SKU WITH (NOLOCK) 
   WHERE StorerKey = @c_StorerKey 
   AND SKU = @c_Sku

   IF @c_SerialNoCapture NOT IN ('1','3') 
      GOTO Quit_SP

   IF @n_Continue IN (1,2)
   BEGIN
      IF @c_FromID <> @c_ToID AND @c_Lot <> ''
      BEGIN
         IF EXISTS(SELECT 1 FROM dbo.SerialNo SN WITH (NOLOCK) 
                  WHERE SN.Lot = @c_Lot
                  AND SN.ID = @c_FromID)
         BEGIN              
            DECLARE CUR_SWAP_ID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT SN.SerialNoKey 
            FROM dbo.SerialNo SN WITH (NOLOCK) 
            WHERE SN.LOT = @c_Lot
            AND SN.ID = @c_FromID
            AND SN.StorerKey = @c_StorerKey
            AND SN.SKU = @c_Sku
            -- ORDER BY SN.SerialNoKey
              
            OPEN CUR_SWAP_ID
              
            FETCH NEXT FROM CUR_SWAP_ID INTO @c_SerialNoKey
              
            WHILE @@FETCH_STATUS = 0
            BEGIN
               UPDATE dbo.SerialNo WITH (ROWLOCK)
                  SET ID = @c_ToID, EditDate=GETDATE(), EditWho=SUSER_SNAME()
               WHERE SerialNoKey = @c_SerialNoKey 
               SELECT @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @n_err = 500301
                  SELECT @c_errmsg='NSQL'+CONVERT(char(6),@n_err)+': Update Failed On Table SerialNo. (msp_SerialNoMoveCheck)' 
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@c_ErrMsg),'') + ' ) '
                  BREAK
               END
      

               FETCH NEXT FROM CUR_SWAP_ID INTO @c_SerialNoKey
            END
              
            CLOSE CUR_SWAP_ID
            DEALLOCATE CUR_SWAP_ID
         END
           
      END
   END -- @c_Continue=1

   Quit_SP:
   IF @n_Continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      DECLARE @n_IsRDT INT
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

      IF @n_IsRDT = 1
      BEGIN
         -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
         -- Instead we commit and raise an error back to parent, let the parent decide

         -- Commit until the level we begin with
         -- Notes: Original codes do not have COMMIT TRAN, error will be handled by parent
         -- WHILE @@TRANCOUNT > @n_starttcnt
         --    COMMIT TRAN

         -- Raise error with severity = 10, instead of the default severity 16.
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
         RAISERROR (@n_err, 10, 1) WITH SETERROR

         -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
      END
      ELSE
      BEGIN
         EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'nspItrnAddMoveCheck'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN -1
      END
   END
   ELSE
   BEGIN
      /* Error Did Not Occur , Return Normally */
      SELECT @b_success = 1
      RETURN 0
   END
   /* End Return Statement */
END -- Create Proc 
GO
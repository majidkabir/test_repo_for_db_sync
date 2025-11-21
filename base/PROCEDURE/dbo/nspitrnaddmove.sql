SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspItrnAddMove                                     */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 2.4                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 11-May-2006  MaryVong      Add in RDT compatible error messages      */
/* 07-Sep-2006  MaryVong      Add in RDT compatible error messages      */
/* 22-May-2014  CSCHONG       Add Lottable06-15 (CS01)                  */
/* 12-Feb-2014  YTWan     2.0 SOS#315474 - Project Merlion - Exceed GTM */
/*                            Kiosk Module; ConfirmPick Move (Wan01)    */
/* 14-MAY-2015  YTWan     2.1 SOS#334061 - Project Merlion -            */
/*                            GW - WMS_Move_Check (Wan02)               */
/* 04-Nov-2015  Shong01   2.2 Performance Tuning                        */
/* 04-Nov-2015  YTWan     2.2 Fixed. Add Allow Null when create #Move   */
/*                            temp table (Wan03)                        */
/* 16-Jan-2017  TLTING01  2.3 Performance Tuning and bug fix            */
/* 22-Mar-2018  Wan04     2.4 WMS-4288 - [CN] UA Relocation Phase II -  */
/*                            Exceed Channel of IQC                     */
/* 17-Oct-2019  NJOW01    2.5 WMS-10923 Fix syntax error                */
/************************************************************************/

CREATE PROC    [dbo].[nspItrnAddMove]
@n_ItrnSysId    int
,              @c_StorerKey    NVARCHAR(15)
,              @c_Sku          NVARCHAR(20)
,              @c_Lot          NVARCHAR(10)
,              @c_FromLoc      NVARCHAR(10)
,              @c_FromID       NVARCHAR(18)
,              @c_ToLoc        NVARCHAR(10)
,              @c_ToID         NVARCHAR(18)
,              @c_Status       NVARCHAR(10)
,              @c_lottable01   NVARCHAR(18)
,              @c_lottable02   NVARCHAR(18)
,              @c_lottable03   NVARCHAR(18)
,              @d_lottable04   datetime
,              @d_lottable05   datetime
,              @c_lottable06   NVARCHAR(30)= ''    --(CS01)
,              @c_lottable07   NVARCHAR(30)= ''    --(CS01)
,              @c_lottable08   NVARCHAR(30)= ''    --(CS01)
,              @c_lottable09   NVARCHAR(30)= ''    --(CS01)
,              @c_lottable10   NVARCHAR(30)= ''    --(CS01)
,              @c_lottable11   NVARCHAR(30)= ''    --(CS01)
,              @c_lottable12   NVARCHAR(30)= ''    --(CS01)
,              @d_lottable13   datetime = NULL     --(CS01)
,              @d_lottable14   datetime = NULL     --(CS01)
,              @d_lottable15   datetime = NULL     --(CS01)
,              @n_casecnt      int
,              @n_innerpack    int
,              @n_qty          int
,              @n_pallet       int
,              @f_cube         float
,              @f_grosswgt     float
,              @f_netwgt       float
,              @f_otherunit1   float
,              @f_otherunit2   float
,              @c_SourceKey    NVARCHAR(20)
,              @c_SourceType   NVARCHAR(30)
,              @c_PackKey      NVARCHAR(10)
,              @c_UOM          NVARCHAR(10)
,              @b_UOMCalc      int
,              @d_EffectiveDate datetime
,              @c_itrnkey      NVARCHAR(10)   OUTPUT
,              @b_Success      int        OUTPUT
,              @n_err          int        OUTPUT
,              @c_errmsg       NVARCHAR(250)  OUTPUT
,              @c_MoveRefKey   NVARCHAR(10) = ''      --(Wan01)
,              @c_Channel      NVARCHAR(20) = ''      --(Wan04)
,              @n_Channel_ID   BIGINT = 0 OUTPUT      --(Wan04)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF 

   DECLARE        @n_continue int        ,  
   @n_starttcnt int        , -- Holds the current transaction count
   @c_preprocess NVARCHAR(250) , -- preprocess
   @c_pstprocess NVARCHAR(250) , -- post process
   @n_err2 int              -- For Additional Error Detection

   DECLARE @c_SQL       NVARCHAR(MAX)        --(Wan02)

   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0

   /* #INCLUDE <SPIAM1.SQL> */     
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@d_EffectiveDate)) IS NULL
   BEGIN
      SELECT @d_EffectiveDate = GETDATE()
   END

   IF @n_continue=1 OR @n_continue=2
   BEGIN
      SELECT @b_success = 1
      EXECUTE nspg_getkey
      "ItrnKey"
      , 10
      , @c_ItrnKey OUTPUT
      , @b_success OUTPUT
      , @n_err OUTPUT
      , @c_errmsg OUTPUT
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 62001
         SELECT @c_errmsg = 'nspItrnAddMove: ' + dbo.fnc_RTrim(@c_errmsg)
      END
   END

   IF @n_continue=1 OR @n_continue=2
   BEGIN
      EXEC nspGetPack @c_StorerKey,
      @c_Sku,
      @c_Lot,
      @c_FromLoc,
      @c_FromID,
      @c_PackKey OUTPUT,
      @b_success OUTPUT,
      @n_err OUTPUT,
      @c_errmsg OUTPUT
      IF @b_success = 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 62002
         SELECT @c_errmsg = 'nspItrnAddMove: ' + dbo.fnc_RTrim(@c_errmsg)
      END
   END
   
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      DECLARE @n_UOMQty int
      SELECT @n_UOMQty = 0
      IF @b_UOMCalc = 1
      BEGIN
         SELECT @n_UOMQty = @n_Qty
         SELECT @b_success = 1
         EXECUTE nspUOMConv
         @n_fromqty = @n_qty,
         @c_fromuom = @c_uom,
         @c_touom   = NULL,
         @c_packkey = @c_packkey,
         @n_toqty   = @n_qty OUTPUT,
         @b_success = @b_success OUTPUT,
         @n_err     = @n_err OUTPUT,
         @c_errmsg  = @c_errmsg OUTPUT
         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 62003
            SELECT @c_errmsg = 'nspItrnAddMove: ' + dbo.fnc_RTrim(@c_errmsg)
         END
      END
   END

   --(Wan02) - START

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      -- Shong01 Start 
      IF EXISTS(SELECT 1 
                FROM STORERCONFIG SC (NOLOCK) 
                WHERE SC.StorerKey = @c_StorerKey 
                AND SC.Configkey = 'MoveExtendedValidation' 
                AND SC.SValue <> '')
      BEGIN
      -- TLTING01
         CREATE TABLE #MOVE
         (  rowref INT NOT NULL IDENTITY(1,1) PRIMARY KEY
            , StorerKey          NVARCHAR(15)
            ,Sku               NVARCHAR(20)
            ,Lot               NVARCHAR(10)
            ,FromLoc           NVARCHAR(10)
            ,FromID            NVARCHAR(18)
            ,ToLoc             NVARCHAR(10)
            ,ToID              NVARCHAR(18)   
            ,STATUS            NVARCHAR(10)   NULL                 --(Wan03)                
            ,lottable01        NVARCHAR(18)  NULL                 --(Wan03)    
            ,lottable02        NVARCHAR(18)  NULL                 --(Wan03)
            ,lottable03        NVARCHAR(18)  NULL                 --(Wan03)      
            ,lottable04        DATETIME      NULL                 --(Wan03)
            ,lottable05        DATETIME      NULL                 --(Wan03)
            ,lottable06        NVARCHAR(30)  NULL                 --(Wan03)
            ,lottable07        NVARCHAR(30)  NULL                 --(Wan03)
            ,lottable08        NVARCHAR(30)  NULL                 --(Wan03)
            ,lottable09        NVARCHAR(30)  NULL                 --(Wan03)
            ,lottable10        NVARCHAR(30)  NULL                 --(Wan03)
            ,lottable11        NVARCHAR(30)  NULL                 --(Wan03)
            ,lottable12        NVARCHAR(30)  NULL                 --(Wan03)
            ,lottable13        DATETIME      NULL                 --(Wan03)
            ,lottable14        DATETIME      NULL                 --(Wan03)
            ,lottable15        DATETIME      NULL                 --(Wan03)
            ,casecnt           INT           NULL     DEFAULT (0) --(Wan03)
            ,innerpack         INT           NULL     DEFAULT (0) --(Wan03)
            ,qty               INT           NULL     DEFAULT (0) --(Wan03)
            ,pallet            INT           NULL     DEFAULT (0) --(Wan03)
            ,CUBE              FLOAT         NULL     DEFAULT (0) --(Wan03)
            ,grosswgt          FLOAT         NULL     DEFAULT (0) --(Wan03)
            ,netwgt            FLOAT         NULL     DEFAULT (0) --(Wan03)
            ,otherunit1        FLOAT         NULL     DEFAULT (0) --(Wan03)
            ,otherunit2        FLOAT         NULL     DEFAULT (0) --(Wan03)
            ,SourceKey         NVARCHAR(20)  NULL     DEFAULT ('')--(Wan03)
            ,SourceType        NVARCHAR(30)  NULL     DEFAULT ('')--(Wan03)
            ,PackKey           NVARCHAR(10)  NULL     DEFAULT ('')--(Wan03)
            ,UOM               NVARCHAR(10)  NULL     DEFAULT ('')--(Wan03)
            ,UOMCalc           INT           NULL     DEFAULT (0) --(Wan03)
            ,EffectiveDate     DATETIME      NULL                 --(Wan03)
            ,Channel           NVARCHAR(20)  NULL     DEFAULT ('')--(Wan04)
            ) 

         INSERT INTO #MOVE
           (
             StorerKey, Sku, Lot, FromLoc, FromID, ToLoc, ToID, [Status], lottable01, 
             lottable02, lottable03, lottable04, lottable05, lottable06, lottable07, 
             lottable08, lottable09, lottable10, lottable11, lottable12, lottable13, 
             lottable14, lottable15, casecnt, innerpack, qty, pallet, [cube], grosswgt, 
             netwgt, otherunit1, otherunit2, SourceKey, SourceType, PackKey, UOM, UOMCalc, 
             EffectiveDate, Channel)                              --(Wan04)
         VALUES
           (
             @c_StorerKey, @c_Sku, @c_Lot, @c_FromLoc, @c_FromID, @c_ToLoc, @c_ToID, @c_Status, 
             @c_lottable01, @c_lottable02, @c_lottable03, @d_lottable04, @d_lottable05, @c_lottable06, 
             @c_lottable07, @c_lottable08, @c_lottable09, @c_lottable10, @c_lottable11, @c_lottable12, 
             @d_lottable13, @d_lottable14, @d_lottable15, @n_casecnt, @n_innerpack, @n_qty, 
             @n_pallet, @f_cube, @f_grosswgt, @f_netwgt, @f_otherunit1, @f_otherunit2, @c_SourceKey, 
             @c_SourceType, @c_PackKey, @c_UOM, @b_UOMCalc, @d_EffectiveDate, @c_Channel)--(Wan04) 
      END -- Shong01 End


      
      DECLARE @c_MOVEValidationRules  NVARCHAR(30)

      SELECT @c_MOVEValidationRules = SC.sValue
      FROM STORERCONFIG SC (NOLOCK)
      JOIN CODELKUP CL (NOLOCK) ON SC.sValue = CL.Listname
      WHERE SC.StorerKey = @c_StorerKey
      AND SC.Configkey = 'MoveExtendedValidation'

      IF ISNULL(@c_MOVEValidationRules,'') <> ''
      BEGIN
         EXEC isp_MOVE_ExtendedValidation @c_Lot = @c_Lot
                                        , @c_FromLoc = @c_FromLoc
                                        , @c_FromID  = @c_FromID
                                        , @c_MOVEValidationRules=@c_MOVEValidationRules 
                                        , @b_Success = @b_Success OUTPUT
                                        , @c_ErrMsg  = @c_ErrMsg OUTPUT
    
         IF @b_Success <> 1
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 62004
         END
      END
      ELSE   
      BEGIN
         SELECT @c_MOVEValidationRules = SC.sValue    
         FROM STORERCONFIG SC (NOLOCK) 
         WHERE SC.StorerKey = @c_StorerKey 
         AND SC.Configkey = 'MoveExtendedValidation'    
         
         IF EXISTS (SELECT 1 FROM dbo.sysobjects WITH (NOLOCK) WHERE name = RTRIM(@c_MOVEValidationRules) AND type = 'P')          
         BEGIN          
            SET @c_SQL = 'EXEC ' + @c_MOVEValidationRules + ' @c_Lot, @c_FromLoc, @c_FromID,'
                       + '@b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '   --NJOW01

            EXEC sp_executesql @c_SQL,          
                 N'@c_Lot NVARCHAR(10), @c_FromLoc NVARCHAR(10), @c_FromID NVARCHAR(18) 
                  ,@b_Success Int OUTPUT, @n_Err Int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT'  
               ,  @c_Lot
               ,  @c_FromLoc
               ,  @c_FromID        
               ,  @b_Success  OUTPUT           
               ,  @n_Err      OUTPUT          
               ,  @c_ErrMsg   OUTPUT 
                                              

            IF @b_Success <> 1     
            BEGIN    
               SET @n_Continue = 3    
               SET @n_err = 62005     
            END         
         END  
      END            
   END --    IF @n_Continue = 1 OR @n_Continue = 2
   --(Wan02) - END

   IF @n_continue=1 OR @n_continue=2
   BEGIN
      BEGIN TRANSACTION
      IF @n_ItrnSysId IS NULL
      BEGIN
         SELECT @n_ItrnSysId = RAND() * 2147483647
      END

      INSERT itrn
      (        ItrnKey
      ,        ItrnSysId
      ,        TranType
      ,        StorerKey
      ,        Sku
      ,        Lot
      ,        FromLoc
      ,        FromID
      ,        ToLoc
      ,        ToID
      ,        Status
      ,        lottable01
      ,        lottable02
      ,        lottable03
      ,        lottable04
      ,        lottable05
      ,        lottable06     --(CS01)
      ,        lottable07     --(CS01)
      ,        lottable08     --(CS01)
      ,        lottable09     --(CS01)
      ,        lottable10     --(CS01)
      ,        lottable11     --(CS01)
      ,        lottable12     --(CS01)
      ,        lottable13     --(CS01)
      ,        lottable14     --(CS01)
      ,        lottable15     --(CS01)
      ,        casecnt
      ,        innerpack
      ,        Qty
      ,        pallet
      ,        cube
      ,        grosswgt
      ,        netwgt
      ,        otherunit1
      ,        otherunit2
      ,        SourceKey
      ,        SourceType
      ,        PackKey
      ,        UOM
      ,        UOMCalc
      ,        UOMQty
      ,        EffectiveDate
      ,        MoveRefKey           --(wan01)
      ,        Channel              --(Wan04)
      ,        Channel_ID           --(Wan04)
      )
      VALUES (
               @c_ItrnKey
      ,        @n_ItrnSysId
      ,        "MV"
      ,        @c_StorerKey
      ,        @c_Sku
      ,        @c_Lot
      ,        @c_FromLoc
      ,        @c_fromID
      ,        @c_ToLoc
      ,        @c_ToID
      ,        dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Status))
      ,        @c_lottable01
      ,        @c_lottable02
      ,        @c_lottable03
      ,        @d_lottable04
      ,        @d_lottable05
      ,        @c_lottable06     --(CS01)
      ,        @c_lottable07     --(CS01)
      ,        @c_lottable08     --(CS01)
      ,        @c_lottable09     --(CS01)
      ,        @c_lottable10     --(CS01)
      ,        @c_lottable11     --(CS01)
      ,        @c_lottable12     --(CS01)
      ,        @d_lottable13     --(CS01)
      ,        @d_lottable14     --(CS01)
      ,        @d_lottable15     --(CS01)
      ,        @n_casecnt
      ,        @n_innerpack
      ,        @n_Qty
      ,        @n_pallet
      ,        @f_cube
      ,        @f_grosswgt
      ,        @f_netwgt
      ,        @f_otherunit1
      ,        @f_otherunit2
      ,        @c_SourceKey
      ,        @c_SourceType
      ,        @c_PackKey
      ,        @c_UOM
      ,        @b_UOMCalc
      ,        @n_UOMQty
      ,        @d_EffectiveDate
      ,        @c_MoveRefKey           --(Wan01)    
      ,        @c_Channel              --(Wan04)
      ,        @n_Channel_ID           --(Wan04)  
      )
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
      END
      --(Wan04) - START
      ELSE
      BEGIN
         SELECT @n_Channel_ID= i.Channel_ID 
         FROM ITRN AS i WITH(NOLOCK)
         WHERE i.ItrnKey = @c_ItrnKey
      END
      --(Wan04) - END
   END -- @n_continue =1 or @n_continue = 2

   /* #INCLUDE <SPIAM2.SQL> */
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      DECLARE @n_IsRDT INT
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT
   
      IF @n_IsRDT = 1
      BEGIN
         -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
         -- Instead we commit and raise an error back to parent, let the parent decide
   
         -- Commit until the level we begin with
         WHILE @@TRANCOUNT > @n_starttcnt
            COMMIT TRAN
   
         -- Raise error with severity = 10, instead of the default severity 16. 
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
         RAISERROR (@n_err, 10, 1) WITH SETERROR 
   
         -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
      END
      ELSE
      BEGIN
         IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
         BEGIN
            ROLLBACK TRAN
         END
         ELSE
         BEGIN
            WHILE @@TRANCOUNT > @n_starttcnt
            BEGIN
               COMMIT TRAN
            END
         END
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspItrnAddMove'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
   /* End Return Statement */
END

GO
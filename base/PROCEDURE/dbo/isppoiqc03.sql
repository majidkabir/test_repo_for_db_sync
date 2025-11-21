SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* StoredProc: ispPOIQC03                                               */
/* Creation Date: 18-Nov-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-18386 - [CN] MAST VS Add New Trigger Point in IQC &     */
/*          Generate Transmitlog2 for AGV Integration                   */
/*                                                                      */
/* Called By: ispPostFinalizeIQCWrapper                                 */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 18-Nov-2021  WLChooi   1.0 DevOps Combine Script                     */
/* 21-Oct-2022  CHONGCS   1.1 WMS-21036 revised field logic (CS01)      */
/************************************************************************/
CREATE   PROC [dbo].[ispPOIQC03]
            @c_QC_Key         NVARCHAR(10)
         ,  @b_Success        INT = 1  OUTPUT
         ,  @n_err            INT = 0  OUTPUT
         ,  @c_errmsg         NVARCHAR(215) = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt            INT
         , @n_Continue             INT
         , @c_Storerkey            NVARCHAR(15)
         , @c_Facility             NVARCHAR(5)
         , @c_ToLoc                NVARCHAR(10)
         , @c_PostFinalizeIQCSP    NVARCHAR(50)
         , @c_Option1              NVARCHAR(50) = ''
         , @c_Option2              NVARCHAR(50) = ''
         , @c_Option3              NVARCHAR(50) = ''
         , @c_Option4              NVARCHAR(50) = ''
         , @c_Option5              NVARCHAR(4000) = ''
         , @c_TableName            NVARCHAR(20) = 'WSIQCAGV'
         , @c_trmlogkey            NVARCHAR(10) = ''
         , @n_CountBUSR9           INT = 0
         , @c_chkbusr9             NVARCHAR(1) = 'Y'   --CS01
         , @c_clklong              NVARCHAR(250) =''   --CS01

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SELECT @c_Storerkey = IQC.StorerKey
        , @c_Facility  = IQC.to_facility
   FROM InventoryQC IQC (NOLOCK)
   WHERE IQC.QC_Key = @c_QC_Key

   --Check Storerconfig set up with Storerkey + Facility
   EXEC nspGetRight
      @c_Facility          -- facility
   ,  @c_Storerkey         -- Storerkey
   ,  NULL                 -- Sku
   ,  'PostFinalizeIQCSP'  -- Configkey
   ,  @b_Success           OUTPUT
   ,  @c_PostFinalizeIQCSP OUTPUT
   ,  @n_Err               OUTPUT
   ,  @c_ErrMsg            OUTPUT
   ,  @c_Option1           OUTPUT
   ,  @c_Option2           OUTPUT
   ,  @c_Option3           OUTPUT
   ,  @c_Option4           OUTPUT
   ,  @c_Option5           OUTPUT

   IF ISNULL(@c_PostFinalizeIQCSP,'') <> 'ispPOIQC03'
   BEGIN
      GOTO QUIT_SP
   END

   IF EXISTS (SELECT 1
              FROM InventoryQC IQC (NOLOCK)
              JOIN InventoryQCDetail IQD (NOLOCK) ON IQC.QC_Key = IQD.QC_Key
              JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'AGVDEFLoc' AND IQC.to_facility = CL.Code
                                       AND CL.Storerkey = IQC.StorerKey AND CL.Long = IQD.ToLoc
              WHERE IQC.QC_Key = @c_QC_Key)
   BEGIN
      SET @n_Continue = 1
   END
   ELSE
   BEGIN
      GOTO QUIT_SP
   END

   --CS01 S
      SELECT @c_clklong = ISNULL(CL.Long,'')
       FROM InventoryQCDetail IQD (NOLOCK)
   JOIN SKU (NOLOCK) ON SKU.StorerKey = IQD.StorerKey AND SKU.SKU = IQD.SKU
   JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'AGVSKUCAT' AND CL.Storerkey = @c_Storerkey
                            AND CL.Long = SKU.BUSR9
   WHERE IQD.QC_Key = @c_QC_Key  

   IF ISNULL(@c_clklong,'') = '' OR  ISNULL(@c_clklong,'') = 'All'
   BEGIN
         GOTO QUIT_SP
   END

   --CS01 E
      

   SELECT @n_CountBUSR9 = COUNT(DISTINCT SKU.BUSR9)
   FROM InventoryQCDetail IQD (NOLOCK)
   JOIN SKU (NOLOCK) ON SKU.StorerKey = IQD.StorerKey AND SKU.SKU = IQD.SKU
   JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'AGVSKUCAT' AND CL.Storerkey = @c_Storerkey
                            AND CL.Long = SKU.BUSR9
   WHERE IQD.QC_Key = @c_QC_Key

   IF @n_CountBUSR9 > 0
   BEGIN
      SELECT @b_success = 1
      EXECUTE nspg_getkey
         'TransmitlogKey2'
         , 10
         , @c_trmlogkey OUTPUT
         , @b_success   OUTPUT
         , @n_err       OUTPUT
         , @c_errmsg    OUTPUT

      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63820   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                          + ': Unable to Obtain transmitlogkey. (ispPOIQC03) ( SQLSvr MESSAGE='
                          + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
      ELSE
      BEGIN
         IF @n_Continue = 1 OR @n_Continue = 2
         BEGIN
            INSERT INTO Transmitlog2 (transmitlogkey, tablename, key1, key2, key3, transmitflag, TransmitBatch)
            VALUES (@c_trmlogkey, @c_TableName, @c_QC_Key, '', @c_Storerkey, '0', '')

            IF @@ERROR <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63825   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                                + ': Unable to insert into Transmitlog2 table. (ispPOIQC03) ( SQLSvr MESSAGE='
                                + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
         END
      END
   END
   ELSE
   BEGIN
      GOTO QUIT_SP
   END

QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPOIQC03'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO
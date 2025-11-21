SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispMBD02                                                */
/* Creation Date: 07-AUG-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-2577 - GBG bebe ¿C Generate External MBOL Key            */
/*        :                                                             */
/* Called By: MBOLDetail Add, Update, Delete                            */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[ispMBD02]
      @c_Action      NVARCHAR(10)   
  ,   @c_Storerkey   NVARCHAR(15)
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT   
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         , @n_Min             INT
         , @n_Max             INT
         , @n_Fieldlength     INT
         , @n_Batch           INT

         , @c_STRConfigKey    NVARCHAR(30)
         , @c_MBOLKey         NVARCHAR(10) 
         , @c_ExternMBOLKey   NVARCHAR(30)
         , @c_PreFix          NVARCHAR(30)
         , @c_KeyName         NVARCHAR(30)
         , @c_Min             NVARCHAR(30)
         , @c_Max             NVARCHAR(30)
         , @c_KeyString       NVARCHAR(30)

         , @CUR_MBD           CURSOR

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   SET @c_KeyName  = ''
   SET @c_ExternMBOLKey = ''

   CREATE TABLE #TMP_MBOL
   (  MBOLKey  NVARCHAR(10)   NOT NULL PRIMARY KEY )


   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL 
   OR OBJECT_ID('tempdb..#DELETED')  IS NULL
   BEGIN
      GOTO QUIT_SP
   END

   IF @c_Action IN ('UPDATE','DELETE')
   BEGIN 
      GOTO QUIT_SP
   END

   SET @c_STRConfigKey = 'MBOLDetailTrigger_SP'
   EXECUTE dbo.nspGetRight  
               @c_Facility  = NULL       
            ,  @c_Storerkey = @c_StorerKey         -- Storer
            ,  @c_Sku       = ''                   -- Sku
            ,  @c_ConfigKey = @c_STRConfigKey      -- ConfigKey
            ,  @b_success   = @b_success     OUTPUT
            ,  @c_authority = ''        
            ,  @n_err       = @n_err         OUTPUT
            ,  @c_errmsg    = @c_errmsg      OUTPUT
            ,  @c_Option1   = @c_PreFix      OUTPUT 
            ,  @c_Option2   = @c_KeyName     OUTPUT
            ,  @c_Option3   = @c_Min         OUTPUT
            ,  @c_Option4   = @c_Max         OUTPUT

   IF @b_success <> 1
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 60010
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error executing nspGetRight. (ispMBD02)'
      GOTO QUIT_SP
   END
   
   SET @c_PreFix = ISNULL(RTRIM(@c_PreFix),'')

   SET @n_Min = 0
   SET @n_Max = 0
   IF ISNUMERIC(@c_Min) = 1 SET @n_Min = CONVERT(INT, ISNULL(@c_Min,'0'))
   IF ISNUMERIC(@n_Max) = 1 SET @n_Max = CONVERT(INT, ISNULL(@c_Max,'0'))

   IF ISNULL(@c_Min,'') = '' OR ISNULL(@c_Max,'') = '' OR @n_Min <= 0 OR @n_Max <= 0 OR @n_Min > @n_Max 
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 60020
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Invalid Key Range (Min & Max) (ispMBD02)'
      GOTO QUIT_SP
   END 

   SET @n_FieldLength = LEN(RTRIM(ISNULL(@c_Max,'')))
   
   IF ISNULL(RTRIM(@c_KeyName),'') = ''
   BEGIN
      SET @c_KeyName = 'ExMBkey_' + @c_Storerkey 
   END

   INSERT INTO #TMP_MBOL
      (  MBOLKey  )
   SELECT DISTINCT 
         I.MBOLKey
   FROM #INSERTED I 
   JOIN MBOL      M WITH (NOLOCK) ON (I.MBOLKey = M.MBOLKey)
   JOIN ORDERS    O WITH (NOLOCK) ON (I.Orderkey= O.Orderkey)
   WHERE  O.Storerkey = @c_Storerkey
   AND M.Status < '9'
   AND 0 = (SELECT COUNT(1) FROM MBOLDETAIL MBD WITH (NOLOCK) WHERE MBD.MBOLKey = I.MBOLKey
            AND NOT EXISTS (SELECT 1 FROM #INSERTED I2 WHERE MBD.MBOLKey = I2.MBOLKey AND MBD.MBOLLineNumber = I2.MBOLLineNumber)
            )
   ORDER BY I.MBOLKey 

   SELECT @n_Batch = COUNT(1)
   FROM #TMP_MBOL

   IF @n_Batch = 0 
   BEGIN
      GOTO QUIT_SP
   END

   EXEC nspg_GetKeyMinMax 
	   @keyname       = @c_KeyName 
   ,  @fieldlength   = @n_FieldLength
   ,  @Min           = @n_Min
   ,  @Max           = @n_Max
   ,  @keyString     = @c_KeyString    OUTPUT
   ,  @b_Success     = @b_Success      OUTPUT
   ,  @n_err         = @n_err          OUTPUT
   ,  @c_errmsg      = @c_errmsg       OUTPUT
   ,  @n_batch       = @n_Batch
   

   SET @CUR_MBD = CURSOR FAST_FORWARD READ_ONLY FOR 
   SELECT M.MBOLKey
   FROM #TMP_MBOL M 
   ORDER BY M.MBOLKey 
  
   OPEN @CUR_MBD
   
   FETCH NEXT FROM @CUR_MBD INTO @c_MBOLKey 
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_ExternMBOLKey = @c_PreFix + @c_KeyString

      UPDATE MBOL WITH (ROWLOCK)
         SET ExternMBOLKey = @c_ExternMBOLKey
            ,EditWho = SUSER_SNAME()
            ,EditDate= GETDATE()
            ,Trafficcop = NULL
      WHERE MBOLKey = @c_MBOLKey

      SET @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err=60030
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table MBOL. (ispMBD02)' 
         GOTO QUIT_SP
      END

      SET @c_KeyString = RIGHT(REPLICATE('0',@n_Fieldlength) + CONVERT(NVARCHAR(18), CONVERT(INT, @c_KeyString) + 1), @n_Fieldlength)
      FETCH NEXT FROM @CUR_MBD INTO @c_MBOLKey 
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispMBD02'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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
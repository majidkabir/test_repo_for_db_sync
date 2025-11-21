SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_IQCPutaway                                          */
/* Creation Date: 23-FEB-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-4047 - [TW] PNG WMS Function#Inventory QC CR            */
/*        :                                                             */
/* Called By:                                                           */
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
CREATE PROC [dbo].[isp_IQCPutaway]
           @c_QC_Key         NVARCHAR(10)
         --, @c_QCLineNoStart  NVARCHAR(5)
         --, @c_QCLineNoEnd    NVARCHAR(5)
         , @b_Success        INT            OUTPUT
         , @n_Err            INT            OUTPUT
         , @c_ErrMsg         NVARCHAR(255)  OUTPUT
         , @c_Code           NVARCHAR(30) = ''          
         , @b_debug          BIT = 0 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT
         , @n_Continue           INT 

         , @c_Facility           NVARCHAR(5)
         , @c_PhysicalFac        NVARCHAR(5)
         , @c_SuggestLoc         NVARCHAR(10)

         , @c_QCLineNo           NVARCHAR(5)
                              
         , @c_Storerkey          NVARCHAR(15)
         , @c_Sku                NVARCHAR(20)
         , @c_FromLot            NVARCHAR(10)
         , @c_FromLoc            NVARCHAR(10)
         , @c_FromID             NVARCHAR(18)
         , @n_PABookingKey       INT

         , @c_UserName           NVARCHAR(18)

         , @c_QCLineNoStart      NVARCHAR(5)
         , @c_QCLineNoEnd        NVARCHAR(5)

         , @CUR_IQC              CURSOR

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   SET @c_UserName = SUSER_NAME()
   SET @c_QCLineNoStart = '00001'
   SET @c_QCLineNoEnd   = '99999'

   IF EXISTS ( SELECT 1
               FROM  INVENTORYQC IQC WITH (NOLOCK) 
               WHERE IQC.QC_Key = @c_QC_Key
               AND   IQC.finalizeflag <> 'Y'
             )
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 63010
      SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': Inventory QC Has Not Finalized Yet' 
                    + '. (isp_IQCPutaway)' 
      GOTO QUIT_SP
   END

   SET @c_PhysicalFac = ''
   SELECT @c_PhysicalFac = ISNULL(RTRIM(FAC.FacilityFor),'')
   FROM FACILITY     FAC   WITH (NOLOCK)
   JOIN INVENTORYQC  IQC   WITH (NOLOCK) ON (FAC.Facility = IQC.To_Facility)
   WHERE IQC.QC_Key = @c_QC_Key

   IF @c_PhysicalFac = ''
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 63020
      SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': Physical Facility Not Setup for VAS Facility' 
                    + '. (isp_IQCPutaway)' 
      GOTO QUIT_SP
   END

   SET @CUR_IQC = CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT IQCD.QCLineNo
         ,IQC.To_facility
         ,IQCD.Storerkey
         ,IQCD.Sku
         ,IQCD.FromLot
         ,IQCD.ToLoc   -- RF 1819 will move from this loc to suggested loc
         ,IQCD.ToID
   FROM   INVENTORYQC       IQC  WITH (NOLOCK)
   JOIN   INVENTORYQCDETAIL IQCD WITH (NOLOCK) ON (IQC.QC_key = IQCD.QC_Key)
   WHERE  IQC.QC_Key = @c_QC_Key
   AND    IQCD.QCLineNo BETWEEN @c_QCLineNoStart AND @c_QCLineNoEnd
   AND    IQCD.FinalizeFlag = 'Y'
   AND    NOT EXISTS (  SELECT 1
                        FROM RFPUTAWAY RPA WITH (NOLOCK)
                        WHERE RPA.Storerkey = IQCD.Storerkey
                        AND   RPA.Sku       = IQCD.Sku
                        AND   RPA.Lot       = IQCD.FromLot
                        AND   RPA.FromLoc   = IQCD.ToLoc
                        AND   RPA.ID        = IQCD.ToID
                     )
   ORDER BY IQCD.QCLineNo

   OPEN @CUR_IQC
   
   FETCH NEXT FROM @CUR_IQC INTO @c_QCLineNo
                              ,  @c_Facility  -- Stock Sitting Facility
                              ,  @c_Storerkey
                              ,  @c_Sku
                              ,  @c_FromLot
                              ,  @c_FromLoc
                              ,  @c_FromID

   WHILE @@FETCH_STATUS <> -1
   BEGIN

      SET @c_SuggestLoc = ''

      BEGIN TRAN

      IF @b_debug = 1
      BEGIN
         SELECT @c_QCLineNo '@c_QCLineNo'
              , @c_FromLoc '@c_FromLoc', @c_FromID '@c_FromID'
              , @c_PhysicalFac '@c_PhysicalFac'
      END
      BEGIN TRY
         SET @n_PABookingKey = 0
         EXEC rdt.rdt_1819ExtPASP10
            @nMobile          = 999
         ,  @nFunc            = 0
         ,  @cLangCode        = 'ENG'
         ,  @cUserName        = @c_UserName
         ,  @cStorerKey       = @c_Storerkey 
         ,  @cFacility        = @c_Facility           -- Stock Sitting Facility 
         ,  @cFromLOC         = @c_FromLoc            -- IQC to loc = Stock PA From Loc
         ,  @cID              = @c_FromID
         ,  @cSuggLOC         = @c_SuggestLoc   OUTPUT
         ,  @cPickAndDropLOC  = ''
         ,  @cFitCasesInAisle = ''
         ,  @nPABookingKey    = @n_PABookingKey OUTPUT
         ,  @nErrNo           = @n_Err          OUTPUT
         ,  @cErrMsg          = @c_ErrMsg       OUTPUT
         ,  @cToFacility      = @c_PhysicalFac
      END TRY
      BEGIN CATCH
         ROLLBACK TRAN
         --IF @n_Err > 0 --AND @c_SuggestLoc <> ''
         --BEGIN 
            SET @n_Continue = 3
            SET @n_Err = 63030
            SET @c_ErrMsg = ERROR_MESSAGE()

            SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': Error Processing QCKey: ' + RTRIM(@c_QC_Key)
                          + ', Line # ' + RTRIM(@c_QCLineNo)
                          + ' fail. <<' + @c_ErrMsg + '>>'

            GOTO QUIT_SP--NEXT_REC
         --END
      END CATCH

      IF @b_debug = 1
      BEGIN

         SELECT  @c_QCLineNo '@c_QCLineNo'
              , @c_FromLoc '@c_FromLoc', @c_FromID '@c_FromID'
              , @c_SuggestLoc '@c_SuggestLoc', @c_PhysicalFac '@c_PhysicalFac'
              , @n_PABookingKey '@n_PABookingKey' 
      END

      IF @c_SuggestLoc = ''
      BEGIN
         --SET @n_Continue = 3
         --SET @n_Err = 63040
         --SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': Suggest Loc not found.'
         --               + '. (isp_IQCPutaway)' 
         GOTO NEXT_REC
      END

      UPDATE INVENTORYQCDETAIL WITH (ROWLOCK)
      SET UserDefine10 = @n_PABookingKey 
         ,UserDefine09 = @c_SuggestLoc       
         ,EditWho = SUSER_NAME()
         ,EditDate= GETDATE()
         ,TrafficCop = NULL
      WHERE QC_Key = @c_QC_Key
      AND   QCLineNo = @c_QCLineNo

      IF @@ERROR <> 0 
      BEGIN 
         SET @n_Continue = 3
         SET @n_Err = 63050
         SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': Error Update INVENTORYQCDETAIL Fail.'
                        + '. (isp_IQCPutaway)' 
         GOTO QUIT_SP--NEXT_REC
      END      

      NEXT_REC:

      WHILE @@TRANCOUNT > 0 
      BEGIN
         COMMIT TRAN
      END
        
      FETCH NEXT FROM @CUR_IQC INTO @c_QCLineNo
                                 ,  @c_Facility
                                 ,  @c_Storerkey
                                 ,  @c_Sku
                                 ,  @c_FromLot
                                 ,  @c_FromLoc
                                 ,  @c_FromID
   END
   CLOSE @CUR_IQC
   DEALLOCATE @CUR_IQC 
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_IQCPutaway'
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

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO
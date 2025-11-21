SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Store procedure: lsp_CBOL_PopulateMBOL_Wrapper                          */
/* Creation Date: 17-Jul-2024                                              */
/* Copyright : Maersk Logistics                                            */
/* Written by: Shong                                                       */
/*                                                                         */
/* Purpose: UWP-21211 - Analysis: CBOL Migration from Exceed to MWMS V2    */
/*                                                                         */
/* Called By: MWMS Java                                                    */
/*                                                                         */
/* Version: 8.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author   Ver   Purposes                                     */
/***************************************************************************/
CREATE   PROCEDURE [WM].[lsp_CBOL_PopulateMBOL_Wrapper]
	   @n_CBOLKey                 BIGINT
	 , @c_MBOLKey                 NVARCHAR(10)
    , @b_Success                 INT            = 1  OUTPUT
    , @n_Err                     INT            = 0  OUTPUT
    , @c_ErrMsg                  NVARCHAR(250)  = '' OUTPUT
    , @n_WarningNo               INT            = 0  OUTPUT
    , @c_ProceedWithWarning      CHAR(1)        = 'N'
    , @c_UserName                NVARCHAR(128)  = ''
    , @n_ErrGroupKey             INT            = 0  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @n_Continue                 INT = 1
         , @n_StartTCnt                INT = @@TRANCOUNT
         , @c_TableName                NVARCHAR(50)='CBOL'
         , @c_SourceType               NVARCHAR(50)='lsp_CBOL_PopulateMBOL_Wrapper'
         , @c_Refkey1                  NVARCHAR(20)   = ''                   
         , @c_Refkey2                  NVARCHAR(20)   = ''                   
         , @c_Refkey3                  NVARCHAR(20)   = ''                   
         , @c_WriteType                NVARCHAR(50)   = ''                   
         , @n_LogWarningNo             INT            = 0      
         , @n_LogErrNo                 INT            = ''                   
         , @c_LogErrMsg                NVARCHAR(255)  = ''
         , @c_Action                   NVARCHAR(255)  = ''
         , @n_ActionErr                INT            = 0
         , @CUR_ERRLIST                CURSOR                  
   DECLARE
           @c_Facility                 NVARCHAR(5)=''
         , @c_Status                   NVARCHAR(10)=''
         , @c_CBOLReference            NVARCHAR(30)=''
         , @c_StorerKey                NVARCHAR(15)=''
         , @c_GenCBOLRef               NVARCHAR(30)=''
         , @c_CBOLLineNumber           NVARCHAR(5)=''
         , @c_NSqlValue                NVARCHAR(30)=''
         , @c_PRONumber                NVARCHAR(30)=''
         , @c_SealNo                   NVARCHAR(8)='' 
         , @c_VehicleContainer         NVARCHAR(30)=''
         , @c_UserDefine01             NVARCHAR(20)=''
         , @c_CtnType1                 NVARCHAR(30)=''
         , @c_CountedBy                NVARCHAR(10)=''
         , @d_PickupDate               DATETIME
         , @d_DepartureDate            DATETIME
         , @c_RoutingCIDNo             NVARCHAR(30)='' 
         , @c_Carrierkey               NVARCHAR(15)=''
         , @c_SCAC                     NVARCHAR(10)=''
   DECLARE  @t_WMSErrorList   TABLE                                  
         (  RowID             INT            IDENTITY(1,1) 
         ,  TableName         NVARCHAR(50)   NOT NULL DEFAULT('')  
         ,  SourceType        NVARCHAR(50)   NOT NULL DEFAULT('')
         ,  Refkey1           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  Refkey2           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  Refkey3           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  WriteType         NVARCHAR(50)   NOT NULL DEFAULT('')
         ,  LogWarningNo      INT            NOT NULL DEFAULT(0)
         ,  ErrCode           INT            NOT NULL DEFAULT(0)
         ,  Errmsg            NVARCHAR(255)  NOT NULL DEFAULT('')  
         )
   -- Switching SQL User ID from WMCOnnect to User Login ID
   SET  @n_ErrGroupKey = 0
   SET @n_Err = 0
   IF SUSER_SNAME() <> @c_UserName      
   BEGIN
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT
      IF @n_Err <> 0
      BEGIN
         GOTO EXIT_SP
      END
      EXECUTE AS LOGIN = @c_UserName
   END                                   
   SELECT TOP 1 @c_StorerKey = O.StorerKey
   FROM dbo.MBOLDETAIL MD WITH (NOLOCK) 
   JOIN dbo.ORDERS O WITH (NOLOCK) ON MD.OrderKey = O.OrderKey 
   WHERE MD.MbolKey = @c_MBOLKey
   -- Validation 
   SELECT @c_Facility = Facility, 
          @c_Status = [Status],
          @c_CBOLReference = ISNULL(CB.CBOLReference,''),
          @c_PRONumber = CB.ProNumber, 
          @c_SealNo = CB.SealNo, 
          @c_VehicleContainer = CB.VehicleContainer,
          @c_UserDefine01 = CB.UserDefine01,
          @c_CtnType1 = CB.CtnType1,
          @c_CountedBy = CB.CountedBy,
          @d_PickupDate = CB.PickupDate, 
          @d_DepartureDate = CB.DepartureDate,
          @c_RoutingCIDNo = CB.RoutingCIDNo, 
          @c_Carrierkey = CB.Carrierkey, 
          @c_SCAC = CB.SCAC 
   FROM CBOL AS CB (NOLOCK)
   WHERE CBOLKey = @n_CBOLKey 
   IF @c_Status = '9'
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 562301
      SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                     + ': Not Allow Populate, CBOL Aready Shipped.'
                     + '(lsp_CBOL_PopulateMBOL_Wrapper)'
      INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
      VALUES (@c_TableName, @c_SourceType, CAST(@n_CBOLKey AS VARCHAR(10)), @c_MBOLKey, '', 'ERROR', 0, @n_err, @c_errmsg)   
      GOTO EXIT_SP
   END
   SET @c_CBOLLineNumber = ''
   SELECT TOP 1 
      @c_CBOLLineNumber = CBOLLineNumber 
   FROM MBOL WITH (NOLOCK) 
   WHERE  Cbolkey = @n_CBOLKey
   ORDER BY CBOLLineNumber DESC 
   IF ISNULL(@c_CBOLLineNumber, '') = ''
   BEGIN
       SET @c_CBOLLineNumber = '00001'
   END
   ELSE
   BEGIN
       SET @c_CBOLLineNumber = RIGHT('0000' + CAST(CAST(@c_CBOLLineNumber AS INT) + 1 AS VARCHAR(5)), 5)
   END
   BEGIN TRY
      UPDATE MBOL WITH (ROWLOCK)
		   SET CBOLKey = @n_CBOLKey,
		       CBOLLineNumber = @c_CBOLLineNumber,
		       TrafficCop = NULL
	      WHERE MBOLKey = @c_MBOLKey  
      SET @c_Action = 'Updating MBOL with CBOLKey'
      SET @n_ActionErr = 562302
      -- Get Confige Setting sample
      IF ISNULL(@c_CBOLReference,'') = ''
      BEGIN
         SET @c_GenCBOLRef ='0'
         SELECT @c_GenCBOLRef = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'GENCBOLREF')
         IF @c_GenCBOLRef ='1'
         BEGIN
            EXEC isp_GetVICS_CBOL @n_CBOLKey   = @n_CBOLKey
                                , @c_Facility  = @c_Facility
                                , @c_StorerKey = @c_StorerKey
                                , @c_VICS_CBOL = @c_CBOLReference OUTPUT
         END       
      END
      SELECT @c_NSqlValue = nsqlvalue
      FROM NSQLCONFIG (NOLOCK)
      WHERE configkey = 'CBOLREF2MBOL';
      IF @c_NSqlValue='1'
      BEGIN
         IF ISNULL(TRIM(@c_RoutingCIDNo),'') = ''
         BEGIN
		 	   SELECT @c_RoutingCIDNo = MIN(BookingReference)
			   FROM MBOL (NOLOCK)
			   WHERE CBOLKEY = @n_CBOLKey 
			   HAVING COUNT(DISTINCT BookingReference) = 1
         END
         IF ISNULL(TRIM(@c_Carrierkey),'') = ''
         BEGIN
		 	   SELECT @c_Carrierkey = MIN(OtherReference)
			   FROM MBOL (NOLOCK)
			   WHERE CBOLKEY = @n_CBOLKey 
			   HAVING COUNT(DISTINCT OtherReference) = 1
         END
         IF ISNULL(TRIM(@c_SCAC),'') = ''  
         BEGIN
		 	   SELECT @c_SCAC = MIN(Carrierkey)
			   FROM MBOL (NOLOCK)
			   WHERE CBOLKEY = @n_CBOLKey
			   HAVING COUNT(DISTINCT Carrierkey) = 1          
         END
		   IF ISNULL(TRIM(@c_SCAC),'') = '' 
         BEGIN
			   SELECT @c_SCAC = MIN(VoyageNumber)		 
			   FROM MBOL (NOLOCK)
			   WHERE CBOLKEY = @n_CBOLKey
			   HAVING COUNT(DISTINCT VoyageNumber) = 1          
         END
 		   IF ISNULL(TRIM(@c_SealNo),'') = '' 
         BEGIN
			   SELECT @c_SealNo = MIN(SealNo)	
			   FROM MBOL (NOLOCK)
			   WHERE CBOLKEY = @n_CBOLKey
			   HAVING COUNT(DISTINCT SealNo) = 1           
         END
         IF ISNULL(TRIM(@c_VehicleContainer),'') = '' 
         BEGIN
			   SELECT @c_VehicleContainer = MIN(ContainerNo)						 
			   FROM MBOL (NOLOCK)
			   WHERE CBOLKEY = @n_CBOLKey
			   HAVING COUNT(DISTINCT ContainerNo) = 1
         END 
         IF ISNULL(TRIM(@c_UserDefine01),'') = '' 
         BEGIN
			   SELECT @c_UserDefine01 = MIN(PlaceOfLoading)								
			   FROM MBOL (NOLOCK)
			   WHERE CBOLKEY = @n_CBOLKey
			   HAVING COUNT(DISTINCT PlaceOfLoading) = 1          
         END
         IF ISNULL(TRIM(@c_CtnType1),'') = '' 
         BEGIN
			   SELECT @c_CtnType1 = MIN(CtnType1)								
			   FROM MBOL (NOLOCK)
			   WHERE CBOLKEY = @n_CBOLKey
			   HAVING COUNT(DISTINCT CtnType1) = 1          
         END
         IF ISNULL(TRIM(@c_CountedBy),'') = '' 
         BEGIN
			   SELECT @c_CountedBy = MIN(TransMethod)								
			   FROM MBOL (NOLOCK)
			   WHERE CBOLKEY = @n_CBOLKey
			   HAVING COUNT(DISTINCT TransMethod) = 1          
         END
         IF @d_PickupDate IS NULL
         BEGIN
			   SELECT @d_PickupDate = MIN(Userdefine07)								
			   FROM MBOL (NOLOCK)
			   WHERE CBOLKEY = @n_CBOLKey
			   HAVING COUNT(DISTINCT CONVERT(VARCHAR(10),Userdefine07,112)) = 1          
         END
         IF @d_DepartureDate IS NULL
         BEGIN
			   SELECT @d_DepartureDate = MIN(departuredate)								
			   FROM MBOL (NOLOCK)
			   WHERE CBOLKEY = @n_CBOLKey
			   HAVING COUNT(DISTINCT CONVERT(VARCHAR(10),departuredate,112)) = 1          
         END
          UPDATE MBOL 
            SET BookingReference= CASE WHEN ISNULL(@c_RoutingCIDNo,'') <> '' THEN @c_RoutingCIDNo ELSE BookingReference END, 
                OtherReference = CASE WHEN ISNULL(@c_Carrierkey,'') <> '' THEN @c_Carrierkey ELSE OtherReference END,
                Carrierkey = CASE WHEN ISNULL(@c_SCAC,'') <> '' THEN @c_SCAC ELSE Carrierkey END,
                VoyageNumber = CASE WHEN ISNULL(@c_PRONumber,'') <> '' THEN @c_PRONumber ELSE VoyageNumber END,
                SealNo = CASE WHEN ISNULL(@c_SealNo,'') <> '' THEN @c_SealNo ELSE SealNo END,
                ContainerNo = CASE WHEN ISNULL(@c_VehicleContainer,'') <> '' THEN @c_VehicleContainer ELSE ContainerNo END, 
                PlaceOfDelivery = CASE WHEN ISNULL(@c_CBOLReference,'') <> '' THEN @c_CBOLReference ELSE PlaceOfDelivery END, 
                Userdefine07 = CASE WHEN ISNULL(@d_PickupDate,'') <> '' THEN @d_PickupDate ELSE Userdefine07 END,
                DepartureDate = CASE WHEN ISNULL(@d_DepartureDate,'') <> '' THEN @d_DepartureDate ELSE Userdefine07 END,
                PlaceOfLoading = CASE WHEN ISNULL(@c_UserDefine01,'') <> '' THEN @c_UserDefine01 ELSE PlaceOfLoading END,
                CtnType1 = CASE WHEN ISNULL(@c_CtnType1,'') <> '' THEN @c_CtnType1 ELSE CtnType1 END,
                TransMethod = CASE WHEN ISNULL(@c_CountedBy,'') <> '' THEN @c_CountedBy ELSE TransMethod END
         WHERE CBOLKey = @n_CBOLKey 
         SET @c_Action = 'Updating MBOL'
         SET @n_ActionErr = 562303
          UPDATE CBOL 
            SET RoutingCIDNo= CASE WHEN ISNULL(RoutingCIDNo,'') = '' THEN @c_RoutingCIDNo ELSE RoutingCIDNo END, 
                Carrierkey = CASE WHEN ISNULL(Carrierkey,'') = '' THEN @c_Carrierkey ELSE Carrierkey END,
                SCAC = CASE WHEN ISNULL(SCAC,'') = '' THEN @c_SCAC ELSE SCAC END,
                PRONumber = CASE WHEN ISNULL(PRONumber,'') = '' THEN @c_PRONumber ELSE PRONumber END,
                SealNo = CASE WHEN ISNULL(SealNo,'') = '' THEN @c_SealNo ELSE SealNo END,
                VehicleContainer = CASE WHEN ISNULL(VehicleContainer,'') = '' THEN @c_VehicleContainer ELSE VehicleContainer END, 
                CBOLReference = CASE WHEN ISNULL(CBOLReference,'') = '' THEN @c_CBOLReference ELSE CBOLReference END, 
                PickupDate = CASE WHEN ISNULL(PickupDate,'') = '' THEN @d_PickupDate ELSE PickupDate END,
                DepartureDate = CASE WHEN ISNULL(DepartureDate,'') = '' THEN @d_DepartureDate ELSE Userdefine07 END,
                UserDefine01 = CASE WHEN ISNULL(UserDefine01,'') = '' THEN @c_UserDefine01 ELSE UserDefine01 END,
                CtnType1 = CASE WHEN ISNULL(CtnType1,'') = '' THEN @c_CtnType1 ELSE CtnType1 END,
                CountedBy = CASE WHEN ISNULL(CountedBy,'') = '' THEN @c_CountedBy ELSE CountedBy END
         WHERE CBOLKey = @n_CBOLKey 
         SET @c_Action = 'Updating CBOL'
         SET @n_ActionErr = 562304
      END
   END TRY
   BEGIN CATCH
      IF (XACT_STATE()) = -1
      BEGIN
         ROLLBACK TRAN
      END
      WHILE @@TRANCOUNT < @n_StartTCNT
      BEGIN
         BEGIN TRAN
      END
      SET @n_Continue = 3
      SET @n_err = @n_ActionErr
      SET @c_ErrMsg = ERROR_MESSAGE()
      SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                     + RTRIM(@c_Action) + ' Fail! (' + @c_ErrMsg + ')'
   END CATCH
   IF @b_success = 0 OR @n_Err <> 0
   BEGIN
      INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
      VALUES (@c_TableName, @c_SourceType, @c_MbolKey, CAST(@n_Cbolkey AS VARCHAR(10)), '', 'ERROR', 0, @n_err, @c_errmsg) 
      SET @n_Continue = 3
      GOTO EXIT_SP
   END
   IF @n_Continue = 3
   BEGIN
      GOTO EXIT_SP
   END
   EXIT_SP:
   IF (XACT_STATE()) = -1               
   BEGIN
      SET @n_continue = 3
      ROLLBACK TRAN
   END                                  
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @n_StartTCnt = 1 AND @@TRANCOUNT > @n_StartTCnt              
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_CBOL_PopulateMBOL_Wrapper '
      SET @n_WarningNo = 0
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt                              
      BEGIN
         COMMIT TRAN
      END
   END
   SET @CUR_ERRLIST = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT   twl.TableName         
         ,  twl.SourceType        
         ,  twl.Refkey1           
         ,  twl.Refkey2           
         ,  twl.Refkey3           
         ,  twl.WriteType         
         ,  twl.LogWarningNo      
         ,  twl.ErrCode           
         ,  twl.Errmsg               
   FROM @t_WMSErrorList AS twl
   ORDER BY twl.RowID
   OPEN @CUR_ERRLIST
   FETCH NEXT FROM @CUR_ERRLIST INTO   @c_TableName         
                                     , @c_SourceType        
                                     , @c_Refkey1           
                                     , @c_Refkey2           
                                     , @c_Refkey3           
                                     , @c_WriteType         
                                     , @n_LogWarningNo      
                                     , @n_LogErrNo           
                                     , @c_LogErrMsg           
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      EXEC [WM].[lsp_WriteError_List] 
         @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
      ,  @c_TableName   = @c_TableName
      ,  @c_SourceType  = @c_SourceType
      ,  @c_Refkey1     = @c_Refkey1
      ,  @c_Refkey2     = @c_Refkey2
      ,  @c_Refkey3     = @c_Refkey3
      ,  @n_LogWarningNo= @n_LogWarningNo
      ,  @c_WriteType   = @c_WriteType
      ,  @n_err2        = @n_LogErrNo 
      ,  @c_errmsg2     = @c_LogErrMsg 
      ,  @b_Success     = @b_Success    
      ,  @n_err         = @n_err        
      ,  @c_errmsg      = @c_errmsg         
      FETCH NEXT FROM @CUR_ERRLIST INTO   @c_TableName         
                                        , @c_SourceType        
                                        , @c_Refkey1           
                                        , @c_Refkey2           
                                        , @c_Refkey3           
                                        , @c_WriteType         
                                        , @n_LogWarningNo      
                                        , @n_LogErrNo           
                                        , @c_LogErrmsg     
   END
   CLOSE @CUR_ERRLIST
   DEALLOCATE @CUR_ERRLIST
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
   REVERT
END -- End Procedure

GO
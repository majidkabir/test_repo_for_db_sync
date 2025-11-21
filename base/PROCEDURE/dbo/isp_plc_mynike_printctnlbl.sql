SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_PLC_MYNIKE_PrintCTNLBL                         */
/* Creation Date: 06-JUL-2021                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-17432 MY Nike PLC print carton label                    */
/*													                                            */
/*                                                                      */
/* Input Parameters:  @c_DataStream       - ''                          */
/*                    @c_StorerKey        - ''                          */
/*                    @n_WSDTKey          - 0                           */
/*                    @c_BatchNo          - ''                          */
/*                    @b_Debug            - 0                           */
/*                                                                      */
/* Output Parameters: @c_InvalidFlag      - InvalidFlag   = 'N'         */
/*                    @b_Success          - Success Flag  = 0           */
/*                    @n_Err              - Error Code    = 0           */
/*                    @c_ErrMsg           - Error Message = ''          */
/*                    @c_ResponseString   - Error Message = ''          */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.1                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author  Ver  Purposes                                    */
/* 17-Jan-2022 NJOW    1.0  DEVOPS combine script                       */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_PLC_MYNIKE_PrintCTNLBL](
           @n_SerialNo           INT
         , @c_MessageID          NVARCHAR(10)     
         , @c_MessageName        NVARCHAR(15)     
         , @c_RespondMsg         NVARCHAR(MAX)     = ''  OUTPUT     
         , @b_Success            INT               = 1   OUTPUT
         , @n_Err                INT               = 0   OUTPUT
         , @c_ErrMsg             NVARCHAR(250)     = ''  OUTPUT
)
AS  
BEGIN
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue                 INT
         , @n_StartTCnt                INT    
         , @b_debug                    INT     

   SELECT @n_StartTCnt = @@TRANCOUNT, @n_Continue = 1, @b_Success = 0, @n_err = 0, @c_ErrMsg = '', @b_debug = 0
   
   DECLARE @c_Storerkey      NVARCHAR(15),
           @c_CartonID       NVARCHAR(20),
           @c_Data           NVARCHAR(MAX),
           @c_ConveyorLaneNo NVARCHAR(20),
           @c_RDTUserName    NVARCHAR(128),
           @c_PrinterID      NVARCHAR(10),
           @c_Pickslipno     NVARCHAR(10) 
           
   SELECT @c_Data = Data
   FROM dbo.TCPSocket_INLog WITH (NOLOCK)
   WHERE SerialNo = @n_SerialNo

   SET @c_Data = REPLACE(REPLACE(@c_Data,'<STX>',''),'<ETX>','') --<STX>CTNSCN|MY14041625|00001<ETX>  messagetype|cartonno|lane#
   
   SELECT @c_CartonID   = ColValue FROM dbo.fnc_DelimSplit(';',@c_Data) WHERE SeqNo = 2          
   SELECT @c_ConveyorLaneNo   = ColValue FROM dbo.fnc_DelimSplit(';',@c_Data) WHERE SeqNo = 3
      
   SET @c_RDTUserName = 'PrintNApply' + RTRIM(LTRIM(@c_ConveyorLaneNo))   --fix userid for each lane and printer. 
   
   SELECT @c_PrinterID = U.DefaultPrinter
          --@c_Storerkey = U.DefaultStorer
   FROM RDT.RDTUSER U (NOLOCK)
   JOIN RDT.RDTPRINTER P (NOLOCK) ON U.DefaultPrinter = P.PrinterID
   WHERE U.UserName = @c_RDTUserName
   
   IF @b_debug = 1  
   BEGIN
      SELECT 'Prn Data:'         [Prn Data]  
           , @n_SerialNo         [@n_SerialNo]  
           , @c_CartonID         [@c_CartonID]  
           , @c_MessageName      [@c_MessageName]  
           , @c_ConveyorLaneNo   [@c_ConveyorLaneNo]        
           , @c_PrinterID        [@c_PrinterID]
           , @c_RDTUserName      [@c_RDTUserName]
   END  

   IF ISNULL(@c_PrinterID,'') = ''
   BEGIN
   	  SET @n_continue = 3
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_Err) 
                    + ': DefaultPrinter is not setup for RDT User: ' + RTRIM(ISNULL(@c_RDTUserName,'')) + '. (isp_PLC_MYNIKE_PrintCTNLBL)'
      GOTO QUIT
   END

   /*IF ISNULL(@c_Storerkey,'') = ''
   BEGIN
   	  SET @n_continue = 3
      SET @n_Err = 88510
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_Err) 
                    + ': DefaultStorer is not setup for RDT User: ' + RTRIM(ISNULL(@c_RDTUserName,'')) + '. (isp_PLC_MYNIKE_PrintCTNLBL)'
      GOTO QUIT
   END*/
   
   SELECT TOP 1 @c_Pickslipno = PH.Pickslipno,
                @c_Storerkey = PH.Storerkey
   FROM PACKHEADER PH (NOLOCK)
   JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno    
   WHERE PD.DropID = @c_CartonID
   --AND PH.Storerkey = @c_Storerkey
   ORDER BY PH.EditDate DESC
   
   IF @b_debug = 1  
   BEGIN
      SELECT 'Prn Data2:'        [Prn Data2]  
           , @c_Pickslipno       [@c_Pickslipno]  
           , @c_Storerkey        [@c_Storerkey]  
   END  
   
   IF ISNULL(@c_Pickslipno,'') = ''
   BEGIN
   	  SET @n_continue = 3
      SET @n_Err = 88520
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_Err) 
                    + ': Invalid CartonID: ' + RTRIM(ISNULL(@c_CartonID,'')) + '. (isp_PLC_MYNIKE_PrintCTNLBL)'
      GOTO QUIT
   END 
      
   EXEC  isp_PrintToRDTSpooler                      
        @c_ReportType     = 'UCCLABEL'
     ,  @c_Storerkey      = @c_Storerkey           
     ,  @n_Noofparam      = 4           
     ,  @c_Param01        = @c_Storerkey    --storerkey         
     ,  @c_Param02        = @c_CartonID     --picslipno / dropid          
     ,  @c_Param03        = ''              --from carton       
     ,  @c_Param04        = ''              --to carton
     ,  @c_Param05        = ''             
     ,  @c_Param06        = ''             
     ,  @c_Param07        = ''             
     ,  @c_Param08        = ''             
     ,  @c_Param09        = ''             
     ,  @c_Param10        = ''             
     ,  @n_Noofcopy       = 1            
     ,  @c_UserName       = @c_RDTUserName           
     ,  @c_Facility       = ''            
     ,  @c_PrinterID      = @c_PrinterID           
     ,  @c_Datawindow     = ''                
     ,  @c_IsPaperPrinter = 'N'      
     ,  @c_JobType        = 'TCPSPOOLER'
     ,  @c_PrintData      = ''           
     ,  @b_success        = @b_success   OUTPUT    
     ,  @n_err            = @n_err       OUTPUT    
     ,  @c_errmsg         = @c_errmsg    OUTPUT 
     ,  @n_Function_ID    = 999    -- Print From WMS Setup
       
   IF @b_success <> 1
   BEGIN
   	  SET @n_continue = 3
      GOTO QUIT
   END 
               
   QUIT:

   IF @n_Continue=3  -- Error Occured 
   BEGIN  
      SELECT @b_Success = 0  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt 
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
END --End Procedure

GO
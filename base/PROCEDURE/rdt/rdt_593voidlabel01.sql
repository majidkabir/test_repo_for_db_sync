SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_593VoidLabel01                                     */
/*                                                                         */
/* Modifications log: For Levis                                            */
/*                                                                         */
/* Date        Rev   Author       Purposes                                 */
/* 2024-10-31  1.0   ShaonAn      FCR-1045   Created                       */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_593VoidLabel01] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR( 60),  
   @cParam2    NVARCHAR( 60),
   @cParam3    NVARCHAR( 60),
   @cParam4    NVARCHAR( 60),
   @cParam5    NVARCHAR( 60),
   @nErrNo     INT OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE
        @n_Continue        INT    
      , @n_StartTCnt       INT
      , @b_Success         INT
      , @nInput            INT   
      , @cCartonNo         NVARCHAR(20)
      , @cTrackingNo       NVARCHAR(40)
      , @cOrderKey         NVARCHAR(10)
      , @c_Key1            NVARCHAR(10)
      , @c_Key2            NVARCHAR(30)

   DECLARE @tTrans TABLE(orderKey NVARCHAR(10),labelNo NVARCHAR(20))

   SELECT @n_StartTCnt = @@TRANCOUNT , @n_Continue = 1 

   SELECT
      @cCartonNo = @cParam1,
      @cTrackingNo = @cParam2,
      @cOrderKey = @cParam3

   --Validate
   IF @cCartonNo = '' AND @cTrackingNo = '' AND @cOrderKey = ''
   BEGIN
      SET @nErrNo = 228151
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonNo Need
      GOTO Quit
   END

   IF @cStorerKey = ''
   BEGIN
      SET @nErrNo = 228152
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --StorerKey Lose
      GOTO Quit
   END

   IF @cCartonNo <> ''
   BEGIN
      INSERT INTO @tTrans(orderKey, labelNo)
      SELECT  ph.OrderKey,
              pd.LabelNo 
      FROM dbo.PICKHEADER ph WITH(NOLOCK) 
      INNER JOIN dbo.PackDetail pd WITH(NOLOCK) ON ph.PickHeaderKey = pd.PickSlipNo 
      WHERE pd.LabelNo = @cCartonNo AND ph.StorerKey = @cStorerKey

      SET @nInput = 2
   END
   ELSE IF @cTrackingNo <> ''
   BEGIN
      INSERT INTO @tTrans(orderKey, labelNo)
      SELECT  ph.OrderKey,
              pd.LabelNo 
      FROM dbo.PICKHEADER ph WITH(NOLOCK) 
      INNER JOIN dbo.PackDetail pd WITH(NOLOCK) ON ph.PickHeaderKey = pd.PickSlipNo
      INNER JOIN dbo.CartonTrack ct WITH(NOLOCK) on ct.CarrierRef1 = PD.LabelNo
      WHERE ct.TrackingNo = @cTrackingNo AND ph.StorerKey = @cStorerKey
      
      SET @nInput = 4
   END
   ELSE
   BEGIN
      INSERT INTO @tTrans(orderKey, labelNo)
      SELECT DISTINCT ph.OrderKey, pd.LabelNo 
      FROM dbo.PICKHEADER ph WITH(NOLOCK) 
      INNER JOIN dbo.PackDetail pd WITH(NOLOCK) ON ph.PickHeaderKey = pd.PickSlipNo
      INNER JOIN dbo.CartonTrack ct WITH(NOLOCK) ON ct.CarrierRef1 = pd.LabelNo
      WHERE ph.OrderKey = @cOrderKey AND ph.StorerKey = @cStorerKey

      SET @nInput = 6
   END
    
   BEGIN TRAN     

   IF NOT EXISTS(SELECT 1 FROM @tTrans)
   BEGIN
      SET @nErrNo = 228153
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --StorerKey Lose

      EXEC rdt.rdtSetFocusField @nMobile, @nInput

      GOTO Quit
   END
   ELSE
   BEGIN
      DECLARE CUR_TRMLOG CURSOR LOCAL FAST_FORWARD READ_ONLY FOR             
         SELECT orderKey, labelNo      
         FROM @tTrans      
      
      OPEN CUR_TRMLOG                                                    
                   
      FETCH NEXT FROM CUR_TRMLOG INTO @c_Key1, @c_Key2      
                                                                 
      WHILE @@FETCH_STATUS = 0 AND @n_Continue = 1             
      BEGIN             
         EXEC ispGenTransmitLog2      
              @c_TableName      = 'WSECLDEL',      
              @c_Key1           = @c_Key1,      
              @c_Key2           = @c_Key2,      
              @c_Key3           = @cStorerKey,      
              @c_TransmitBatch  = '',      
              @b_Success        = @b_Success OUTPUT,      
              @n_err            = @nErrNo OUTPUT,      
              @c_errmsg         = @cErrMsg OUTPUT       
             
         IF @b_Success = 0 OR @nErrNo <> 0      
         BEGIN      
            SELECT @n_Continue = 3                                                                                                                                                                    
         END     
        
         FETCH NEXT FROM CUR_TRMLOG INTO  @c_Key1, @c_Key2      
      END      
      CLOSE CUR_TRMLOG      
      DEALLOCATE CUR_TRMLOG
   END

   Quit:

   IF @n_Continue=3  -- Error Occured - Process And Return            
   BEGIN            
      IF @@TRANCOUNT > 0 --AND @@TRANCOUNT > @n_StartTCnt            
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
   END            
   ELSE            
   BEGIN                    
      WHILE @@TRANCOUNT > @n_StartTCnt            
      BEGIN            
         COMMIT TRAN            
      END            
   END                  
END


GO
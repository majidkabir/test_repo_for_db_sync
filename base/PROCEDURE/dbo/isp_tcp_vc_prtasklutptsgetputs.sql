SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  isp_TCP_VC_prTaskLUTPtsGetPuts                     */  
/* Creation Date: 26-Feb-2013                                           */  
/* Copyright: IDS                                                       */  
/* Written by: Shong                                                    */  
/*                                                                      */  
/* Purposes: This message sent following a successful Get Assignment    */
/*           host response                                              */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Purposes                                      */  
/************************************************************************/  
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTPtsGetPuts] (  
    @c_TranDate      NVARCHAR(20)  
   ,@c_DevSerialNo   NVARCHAR(20)  
   ,@c_OperatorID    NVARCHAR(20)
   ,@c_GroupID       NVARCHAR(20)   
   ,@n_SerialNo      INT  
   ,@c_RtnMessage    NVARCHAR(500) OUTPUT      
   ,@b_Success       INT = 1 OUTPUT  
   ,@n_Error         INT = 0 OUTPUT  
   ,@c_ErrMsg        NVARCHAR(255) = '' OUTPUT   
  
)  
AS  
BEGIN  
   DECLARE @c_ErrorCode         NVARCHAR(20) --  0: No error. The VoiceApplication proceeds.  
                                            -- 98: Critical error. If this error is received,   
                                            --     the VoiceApplication speaks the error message, and forces the operator to sign off.   
                                            -- 99: Informational error. The VoiceApplication speaks the informational error message,   
                                            --     but does not force the operator to sign off.  
         , @c_Message            NVARCHAR(400)  
                   
         , @c_Status             NVARCHAR(1) -- N = not put, P = put, S = skipped
         , @c_Sequence           NVARCHAR(10)  
         , @c_LocationID         NVARCHAR(10)  
         , @c_LPN                NVARCHAR(20)  
         , @c_PreAisleLoc        NVARCHAR(50) 
         , @c_Aisle              NVARCHAR(10)  
         , @c_PostAisleLoc       NVARCHAR(50)
         , @c_Slot               NVARCHAR(50)
         , @c_CheckDigit         NVARCHAR(5)           
         , @c_SpokeLocValidate   NVARCHAR(5)
         , @c_ScanLocValidate    NVARCHAR(50)
                     
         , @c_QtyToPut           NVARCHAR(10)  
         , @c_QtyPut             NVARCHAR(10)
         , @c_SKU                NVARCHAR(20)
         , @c_SKUDesc            NVARCHAR(60)
         , @c_UOMDesc            NVARCHAR(50)           
  
         , @c_OverPackAllow      NVARCHAR(1)  
         , @c_ResidualQty        NVARCHAR(10)  

         SET @c_Status           = ''
         SET @c_Sequence         = ''
         SET @c_LocationID       = ''
         SET @c_LPN              = ''
         SET @c_PreAisleLoc      = ''
         SET @c_Aisle            = ''
         SET @c_PostAisleLoc     = ''
         SET @c_Slot             = ''
         SET @c_CheckDigit       = ''
         SET @c_SpokeLocValidate = ''
         SET @c_ScanLocValidate  = ''
         SET @c_QtyToPut         = ''
         SET @c_QtyPut           = ''
         SET @c_SKU              = ''
         SET @c_SKUDesc          = ''
         SET @c_UOMDesc          = ''
         SET @c_OverPackAllow    = ''
         SET @c_ResidualQty      = ''


         SET @c_Status           = 'N'
         SET @c_Sequence         = '7305'
         SET @c_LocationID       = '5002'
         SET @c_LPN              = '9085'
         SET @c_PreAisleLoc      = ''
         SET @c_Aisle            = 'A 1 4 5'
         SET @c_PostAisleLoc     = ''
         SET @c_Slot             = 'Bay 52'
         SET @c_CheckDigit       = '23'
         SET @c_SpokeLocValidate = ''
         SET @c_ScanLocValidate  = ''
         SET @c_QtyToPut         = '2'
         SET @c_QtyPut           = '2'
         SET @c_SKU              = '5555'
         SET @c_SKUDesc          = 'Chocolate'
         SET @c_UOMDesc          = 'Cases'
         SET @c_OverPackAllow    = '0'
         SET @c_ResidualQty      = '0'
              
   SET @c_RtnMessage = ISNULL(RTRIM(@c_Status          ), '') + ',' +
            ISNULL(RTRIM(@c_Sequence        ), '') + ',' +
            ISNULL(RTRIM(@c_LocationID      ), '') + ',' +
            ISNULL(RTRIM(@c_LPN             ), '') + ',' +
            ISNULL(RTRIM(@c_PreAisleLoc     ), '') + ',' +
            ISNULL(RTRIM(@c_Aisle           ), '') + ',' +
            ISNULL(RTRIM(@c_PostAisleLoc    ), '') + ',' +
            ISNULL(RTRIM(@c_Slot            ), '') + ',' +
            ISNULL(RTRIM(@c_CheckDigit      ), '') + ',' +
            ISNULL(RTRIM(@c_SpokeLocValidate), '') + ',' +
            ISNULL(RTRIM(@c_ScanLocValidate ), '') + ',' +
            ISNULL(RTRIM(@c_QtyToPut        ), '') + ',' +
            ISNULL(RTRIM(@c_QtyPut          ), '') + ',' +
            ISNULL(RTRIM(@c_SKU             ), '') + ',' +
            ISNULL(RTRIM(@c_SKUDesc         ), '') + ',' +
            ISNULL(RTRIM(@c_UOMDesc         ), '') + ',' +
            ISNULL(RTRIM(@c_OverPackAllow   ), '') + ',' +
            ISNULL(RTRIM(@c_ResidualQty     ), '') + ',' +
            ISNULL(@c_ErrorCode, 0) + ',' +   
            ISNULL(@c_Message,'')  
                                                
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0   
   BEGIN  
      SET @c_RtnMessage = 'N,7305,5002,9085,,A 1 4 5,,Bay 52,23,,,Cases,0,<CR><LF>' + 
                          'N,7306,5002,7684,,A 1 4 5,,34,23,1,52369,Cases,0,<CR><LF>' + 
                          'N,7307,5005,7684,,A 1 4 7,,45,57,10,14507,Cases,0,' 
   END  
   
 
  
END

GO
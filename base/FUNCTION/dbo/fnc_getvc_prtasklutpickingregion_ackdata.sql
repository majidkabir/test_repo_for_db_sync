SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE FUNCTION [dbo].[fnc_GetVC_prTaskLUTPickingRegion_AckData]  
(  
   @nSerialNo INT  
)  
RETURNS @tPickingRegionTask TABLE   
        (  
       Region                  NVARCHAR(10)  
      ,RegionDescr             NVARCHAR(100)  
      ,AssigmentType           NVARCHAR(1)  
      ,AutoAssign              NVARCHAR(1)            
      ,NoOfAssigmentAllow      NVARCHAR(10)            
      ,SkipAisleAllow          NVARCHAR(1)  
      ,SkipSlotAllow           NVARCHAR(1)  
      ,RepickSkips             NVARCHAR(1)  
      ,PrintLabels             NVARCHAR(20)  
      ,PrintChaseLabels        NVARCHAR(1)  
      ,PickPrompt              NVARCHAR(1)  
      ,SignOffAllow            NVARCHAR(1)  
      ,ContainerType           NVARCHAR(1)  
      ,CloseContainerDeliver   NVARCHAR(1)  
      ,PassAssigment           NVARCHAR(1)  
      ,DeliveryPrompt          NVARCHAR(1)  
      ,VerificationQty         NVARCHAR(1)  
      ,WorkIDLength            NVARCHAR(18)   
      ,ShortsForGoBack         NVARCHAR(1)  
      ,ReversePickAllow        NVARCHAR(1)  
      ,LUT                     NVARCHAR(1)  
      ,CurrentPreAisle         NVARCHAR(50)  
      ,CurrentAisle            NVARCHAR(100)  
      ,CurrentPostAisle        NVARCHAR(50)  
      ,CurrentSlot             NVARCHAR(100)  
      ,MultipleLablesPrint     NVARCHAR(1)  
      ,ContainerIDPrompt       NVARCHAR(1)  
      ,MultipleContainersAllow NVARCHAR(1)  
      ,ContainerValidLength    NVARCHAR(2)  
      ,PickByPickMode          NVARCHAR(1)  
      ,ErrorCode          VARCHAR(20)   
      ,ErrorMessage       NVARCHAR(255)  
        )  
AS  
      
BEGIN  
   DECLARE @c_AckData                  NVARCHAR(4000)  
         , @c_Region                   NVARCHAR(10)  
         , @c_RegionDescr              NVARCHAR(100)  
         , @c_AssigmentType            NVARCHAR(20)  
         , @c_AutoAssign               NVARCHAR(20)           
         , @c_NoOfAssigmentAllow       NVARCHAR(10)            
         , @c_SkipAisleAllow           NVARCHAR(1)  
         , @c_SkipSlotAllow            NVARCHAR(1)  
         , @c_RepickSkips              NVARCHAR(1)  
         , @c_PrintLabels              NVARCHAR(20)  
         , @c_PrintChaseLabels         NVARCHAR(1)  
         , @c_PickPrompt               NVARCHAR(1)  
         , @c_SignOffAllow             NVARCHAR(1)  
         , @c_ContainerType            NVARCHAR(1)  
         , @c_CloseContainerDeliver    NVARCHAR(1)  
         , @c_PassAssigment            NVARCHAR(1)  
         , @c_DeliveryPrompt           NVARCHAR(1)  
         , @c_VerificationQty          NVARCHAR(1)  
         , @c_WorkIDLength             NVARCHAR(18)  
         , @c_ShortsForGoBack          NVARCHAR(1)  
         , @c_ReversePickAllow         NVARCHAR(1)  
         , @c_LUT                      NVARCHAR(1)  
         , @c_CurrentPreAisle          NVARCHAR(50)   
         , @c_CurrentAisle             NVARCHAR(100)   
         , @c_CurrentPostAisle          NVARCHAR(50)   
         , @c_CurrentSlot              NVARCHAR(100)  
         , @c_MultipleLablesPrint      NVARCHAR(1)  
         , @c_ContainerIDPrompt        NVARCHAR(1)  
         , @c_MultipleContainersAllow  NVARCHAR(1)  
         , @c_ContainerValidLength     NVARCHAR(2)  
         , @c_PickByPickMode           NVARCHAR(1)  
         , @c_ErrorCode          VARCHAR(20)  
          ,@c_ErrorMessage       NVARCHAR(255)       
     
   DECLARE @c_Delim CHAR(1), @n_SeqNo INT    
   DECLARE @t_MessageRec TABLE (Seqno INT ,ColValue NVARCHAR(215))      
     
   SET @c_Delim = ','  
     
   SELECT @c_AckData = ti.ACKData  
   FROM   TCPSocket_INLog ti WITH (NOLOCK)  
   WHERE  ti.SerialNo = @nSerialNo      
     
   INSERT INTO @t_MessageRec  
   SELECT *  
   FROM   dbo.fnc_DelimSplit(@c_Delim ,@c_AckData)    
     
   DECLARE @c_SQL       NVARCHAR(4000)  
          ,@n_Index     INT  
          ,@c_ColValue  NVARCHAR(215)  
     
   SET @n_Index = 1  
   SET @c_SQL = ''  
   DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY   
   FOR  
       SELECT SeqNo  
             ,ColValue  
       FROM   @t_MessageRec  
       ORDER BY Seqno  
     
   OPEN CUR1  
     
   FETCH NEXT FROM CUR1 INTO @n_SeqNo, @c_ColValue  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      IF LEFT(@c_ColValue ,1) = N'''' AND RIGHT(RTRIM(@c_ColValue) ,1) = N''''  
         SET @c_ColValue = SUBSTRING(@c_ColValue ,2 ,LEN(RTRIM(@c_ColValue)) - 2)  
         
         IF @n_SeqNo =  1 SET @c_Region                   = @c_ColValue  
         IF @n_Seqno =  2 SET @c_RegionDescr              = @c_ColValue  
         IF @n_Seqno =  3 SET @c_AssigmentType            = @c_ColValue  
         IF @n_Seqno =  4 SET @c_AutoAssign               = @c_ColValue  
         IF @n_Seqno =  5 SET @c_NoOfAssigmentAllow       = @c_ColValue  
         IF @n_Seqno =  6 SET @c_SkipAisleAllow           = @c_ColValue  
         IF @n_Seqno =  7 SET @c_SkipSlotAllow            = @c_ColValue  
         IF @n_Seqno =  8 SET @c_RepickSkips              = @c_ColValue  
         IF @n_Seqno =  9 SET @c_PrintLabels              = CASE @c_ColValue WHEN '0' THEN 'Never' 
                                                                             WHEN '1' THEN 'Begin Assignment'
                                                                             WHEN '2' THEN 'End Assignment'
                                                                             ELSE  @c_ColValue
                                                            END  
         IF @n_Seqno = 10 SET @c_PrintChaseLabels         = @c_ColValue  
         IF @n_Seqno = 11 SET @c_PickPrompt               = @c_ColValue  
         IF @n_Seqno = 12 SET @c_SignOffAllow             = @c_ColValue  
         IF @n_Seqno = 13 SET @c_ContainerType            = @c_ColValue  
         IF @n_Seqno = 14 SET @c_CloseContainerDeliver    = @c_ColValue  
         IF @n_Seqno = 15 SET @c_PassAssigment            = @c_ColValue  
         IF @n_Seqno = 16 SET @c_DeliveryPrompt           = @c_ColValue  
         IF @n_Seqno = 17 SET @c_VerificationQty          = @c_ColValue  
         IF @n_Seqno = 18 SET @c_WorkIDLength             = @c_ColValue  
         IF @n_Seqno = 19 SET @c_ShortsForGoBack          = @c_ColValue  
         IF @n_Seqno = 20 SET @c_ReversePickAllow         = @c_ColValue  
         IF @n_Seqno = 21 SET @c_LUT                      = @c_ColValue  
         IF @n_Seqno = 22 SET @c_CurrentPreAisle          = @c_ColValue  
         IF @n_Seqno = 23 SET @c_CurrentAisle             = @c_ColValue  
         IF @n_Seqno = 24 SET @c_CurrentPostAisle         = @c_ColValue  
         IF @n_Seqno = 25 SET @c_CurrentSlot              = @c_ColValue  
         IF @n_Seqno = 26 SET @c_MultipleLablesPrint      = @c_ColValue  
         IF @n_Seqno = 27 SET @c_ContainerIDPrompt        = @c_ColValue  
         IF @n_Seqno = 28 SET @c_MultipleContainersAllow  = @c_ColValue  
         IF @n_Seqno = 29 SET @c_ContainerValidLength     = @c_ColValue  
         IF @n_Seqno = 30 SET @c_PickByPickMode          = @c_ColValue  
         IF @n_Seqno = 31 SET @c_ErrorCode                = @c_ColValue  
         IF @n_Seqno = 32 SET @c_ErrorMessage             = @c_ColValue  
         
      FETCH NEXT FROM CUR1 INTO @n_SeqNo, @c_ColValue  
   END  
   INSERT INTO @tPickingRegionTask  
   (  
      Region,  
      RegionDescr,  
      AssigmentType,  
      AutoAssign,  
      NoOfAssigmentAllow,  
      SkipAisleAllow,  
      SkipSlotAllow,  
      RepickSkips,  
      PrintLabels,  
      PrintChaseLabels,  
      PickPrompt,  
      SignOffAllow,  
      ContainerType,  
      CloseContainerDeliver,  
      PassAssigment,  
      DeliveryPrompt,  
      VerificationQty,  
      WorkIDLength,  
      ShortsForGoBack,  
      ReversePickAllow,  
      LUT ,  
      CurrentPreAisle ,  
      CurrentAisle,  
      CurrentPostAisle,  
      CurrentSlot,  
      MultipleLablesPrint,  
      ContainerIDPrompt,  
      MultipleContainersAllow,  
      ContainerValidLength,  
      PickByPickMode,  
      ErrorCode,  
      ErrorMessage  
   )  
   VALUES  
   (  
       @c_Region      
      ,@c_RegionDescr                
      ,@c_AssigmentType        
      ,@c_AutoAssign              
      ,@c_NoOfAssigmentAllow                    
      ,@c_SkipAisleAllow                 
      ,@c_SkipSlotAllow               
      ,@c_RepickSkips        
      ,@c_PrintLabels             
      ,@c_PrintChaseLabels      
      ,@c_PickPrompt      
      ,@c_SignOffAllow   
      ,@c_ContainerType    
      ,@c_CloseContainerDeliver     
      ,@c_PassAssigment      
      ,@c_DeliveryPrompt   
      ,@c_VerificationQty   
      ,@c_WorkIDLength    
      ,@c_ShortsForGoBack   
      ,@c_ReversePickAllow   
      ,@c_LUT       
      ,@c_CurrentPreAisle   
      ,@c_CurrentAisle    
      ,@c_CurrentPostAisle  
      ,@c_CurrentSlot  
      ,@c_MultipleLablesPrint  
      ,@c_ContainerIDPrompt   
      ,@c_MultipleContainersAllow  
      ,@c_ContainerValidLength  
      ,@c_PickByPickMode  
      ,@c_ErrorCode             
      ,@c_ErrorMessage    
  
   )  
   CLOSE CUR1  
   DEALLOCATE CUR1  
     
   RETURN  
END;

GO